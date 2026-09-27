import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// A patch that turns one published APK into the next, so an update
/// downloads what changed rather than the whole app.
///
/// 🔴 **Why.** Every update was the full APK, ~50 MB, though between two
/// builds almost nothing in it changes: measured on builds 120 → 121, 5 of
/// its 1,184 files differed, nearly all of that the compiled Dart
/// (libapp.so). The engine, WebRTC and every asset were byte-identical.
/// A patch for that update is about 2 MB.
///
/// ⚠️ **Built to need nothing Android lacks.** No zstd, no bzip2, no native
/// library: the APK had a few hundred KB of room left under its 50 MB
/// ceiling. The format is bsdiff's idea with Deflate, which dart:io has:
///
/// * the new file is walked as runs **aligned** with somewhere in the old
///   one, written as the byte-wise difference from it (compiled code keeps
///   its shape between builds while its addresses shift, so the difference
///   is mostly zeros and deflates to almost nothing), and
/// * **extra** bytes with no counterpart in the old file, written as they
///   are.
///
/// Both halves live here, used by `tool/publish_update.dart` to make a patch
/// and by the updater to apply one, so the two cannot disagree.
///
/// A patch only fits the one old file it was made from, checked by hash
/// before and after, so a phone on any other build, or a patch that fails,
/// takes the full APK instead. See UpdateRepository.
class ApkPatch {
  ApkPatch._();

  static const _magic = [0x44, 0x46, 0x50, 0x31]; // "DFP1"

  /// Header: magic, old size, new size, old SHA-256, new SHA-256, and the
  /// compressed length of each of the three streams.
  static const headerLength = 4 + 8 + 8 + 32 + 32 + 8 * 3;

  // ── Making one ──────────────────────────────────────────────────────

  /// The window hashed to find where new bytes came from in the old file.
  static const _window = 32;

  /// Old positions indexed: every [_sample]th. A run shorter than
  /// _window + _sample may be missed, which only costs a few extra bytes.
  static const _sample = 8;

  /// Aligned runs shorter than this are written as extra bytes instead.
  static const _minRun = 12;

  /// An aligned run ends once this many bytes pass without its match rate
  /// improving: below half matching, the difference stops being cheap.
  static const _patience = 128;

  /// A patch from [old] to [neu].
  static Uint8List create(Uint8List old, Uint8List neu) {
    final index = _Index(old);
    final control = BytesBuilder(copy: false);
    final diff = _Bytes(neu.length);
    final extra = _Bytes(1024 * 1024);

    var oldPos = 0; // where the applier's old cursor is
    var pos = 0; // where we are in the new file
    var extraStart = 0; // the extra bytes not yet written start here
    int? delta; // old - new of the current alignment

    // Extra bytes before the first run have no run to follow, so they get a
    // control entry of their own.
    var pendingSeek = 0;
    var pendingDiff = 0;
    var havePending = false;

    void flush(int end) {
      final extraLen = end - extraStart;
      if (!havePending && extraLen == 0) return;
      if (extraLen > 0) extra.addRange(neu, extraStart, end);
      _varint(control, _zigzag(pendingSeek));
      _varint(control, pendingDiff);
      _varint(control, extraLen);
      havePending = false;
      pendingSeek = 0;
      pendingDiff = 0;
    }

    var hash = 0;
    var hashAt = -1;

    while (pos < neu.length) {
      final d = delta;
      if (d != null) {
        final run = _alignedRun(old, neu, pos, d);
        if (run >= _minRun) {
          flush(pos);
          pendingSeek = pos + d - oldPos;
          pendingDiff = run;
          havePending = true;
          for (var i = 0; i < run; i++) {
            diff.add((neu[pos + i] - old[pos + d + i]) & 0xFF);
          }
          pos += run;
          oldPos = pos + d;
          extraStart = pos;
          continue;
        }
        delta = null;
      }

      if (pos + _window <= neu.length) {
        if (hashAt != pos) {
          hash = _Index.hashAt(neu, pos);
          hashAt = pos;
        }
        final candidate = index.lookup(hash);
        if (candidate >= 0 && _same(old, candidate, neu, pos, _window)) {
          // Back over extra bytes that match too.
          var p = pos, c = candidate;
          while (p > extraStart && c > 0 && neu[p - 1] == old[c - 1]) {
            p--;
            c--;
          }
          pos = p;
          delta = c - p;
          continue;
        }
        if (pos + _window < neu.length) {
          hash = _Index.roll(hash, neu[pos], neu[pos + _window]);
          hashAt = pos + 1;
        }
      }
      pos++;
    }
    flush(neu.length);

    final zControl = _deflate(control.takeBytes());
    final zDiff = _deflate(diff.bytes);
    final zExtra = _deflate(extra.bytes);

    final out = BytesBuilder(copy: false)
      ..add(_magic)
      ..add(_u64(old.length))
      ..add(_u64(neu.length))
      ..add(sha256.convert(old).bytes)
      ..add(sha256.convert(neu).bytes)
      ..add(_u64(zControl.length))
      ..add(_u64(zDiff.length))
      ..add(_u64(zExtra.length))
      ..add(zControl)
      ..add(zDiff)
      ..add(zExtra);
    return out.takeBytes();
  }

  /// How far from [pos] the new file keeps company with the old at offset
  /// [delta]: the length at which (matches × 2 − length) peaked, so the
  /// run keeps going through a few changed bytes and stops once it stops
  /// paying for itself.
  static int _alignedRun(Uint8List old, Uint8List neu, int pos, int delta) {
    final limit = math.min(neu.length - pos, old.length - pos - delta);
    if (pos + delta < 0 || limit <= 0) return 0;
    var score = 0, best = 0, bestLen = 0;
    for (var i = 0; i < limit; i++) {
      score += neu[pos + i] == old[pos + delta + i] ? 1 : -1;
      if (score > best) {
        best = score;
        bestLen = i + 1;
      } else if (i + 1 - bestLen > _patience) {
        break;
      }
    }
    return bestLen;
  }

  static bool _same(Uint8List a, int ai, Uint8List b, int bi, int n) {
    if (ai + n > a.length || bi + n > b.length) return false;
    for (var i = 0; i < n; i++) {
      if (a[ai + i] != b[bi + i]) return false;
    }
    return true;
  }

  // ── Applying one ────────────────────────────────────────────────────

  /// Writes [patch] applied to [old] to [out], and checks it: the old file
  /// must be the one the patch was made from, and the result must be
  /// exactly the file it was made for. Throws [ApkPatchException] if either
  /// is not so, and leaves nothing at [out]. Returns the result's SHA-256.
  static Future<String> apply({
    required File old,
    required File patch,
    required File out,
  }) async {
    final head = await _readHeader(patch);
    final oldLength = await old.length();
    if (oldLength != head.oldSize) {
      throw const ApkPatchException('not the build this patch is from');
    }
    if (await _sha256Of(old) != head.oldHash) {
      throw const ApkPatchException('not the build this patch is from');
    }

    final patchLength = await patch.length();
    if (headerLength + head.controlLength + head.diffLength +
            head.extraLength !=
        patchLength) {
      throw const ApkPatchException('patch is the wrong length');
    }

    final control = await _InflatingReader.open(
        patch, headerLength, head.controlLength);
    final diff = await _InflatingReader.open(
        patch, headerLength + head.controlLength, head.diffLength);
    final extra = await _InflatingReader.open(patch,
        headerLength + head.controlLength + head.diffLength,
        head.extraLength);
    final source = await old.open();
    final sink = await out.open(mode: FileMode.write);
    final hashOut = _HashSink();
    final hasher = sha256.startChunkedConversion(hashOut);

    try {
      const chunk = 64 * 1024;
      final a = Uint8List(chunk), b = Uint8List(chunk);
      var oldPos = 0;
      var written = 0;

      Future<void> emit(Uint8List bytes, int n) async {
        final view = Uint8List.sublistView(bytes, 0, n);
        await sink.writeFrom(view);
        hasher.add(view);
        written += n;
      }

      while (written < head.newSize) {
        final seek = _unzigzag(await control.varint());
        final diffLen = await control.varint();
        final extraLen = await control.varint();
        oldPos += seek;
        if (oldPos < 0 || oldPos + diffLen > head.oldSize ||
            written + diffLen + extraLen > head.newSize) {
          throw const ApkPatchException('patch points outside the file');
        }

        await source.setPosition(oldPos);
        var left = diffLen;
        while (left > 0) {
          final n = math.min(left, chunk);
          await source.readInto(a, 0, n);
          await diff.readInto(b, n);
          for (var i = 0; i < n; i++) {
            a[i] = (a[i] + b[i]) & 0xFF;
          }
          await emit(a, n);
          left -= n;
        }
        oldPos += diffLen;

        left = extraLen;
        while (left > 0) {
          final n = math.min(left, chunk);
          await extra.readInto(a, n);
          await emit(a, n);
          left -= n;
        }
      }
      hasher.close();
      await sink.flush();
    } catch (_) {
      await sink.close();
      await source.close();
      await control.close();
      await diff.close();
      await extra.close();
      if (await out.exists()) await out.delete();
      rethrow;
    }
    await sink.close();
    await source.close();
    await control.close();
    await diff.close();
    await extra.close();

    if (hashOut.digest != head.newHash) {
      await out.delete();
      throw const ApkPatchException('the rebuilt APK is not the new build');
    }
    return head.newHash;
  }

  static Future<_Header> _readHeader(File patch) async {
    final raf = await patch.open();
    try {
      final bytes = await raf.read(headerLength);
      if (bytes.length < headerLength) {
        throw const ApkPatchException('patch is too short');
      }
      for (var i = 0; i < 4; i++) {
        if (bytes[i] != _magic[i]) {
          throw const ApkPatchException('not a Dayflower patch');
        }
      }
      final data = ByteData.sublistView(bytes);
      String hex(int at) => bytes
          .sublist(at, at + 32)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      return _Header(
        oldSize: data.getUint64(4, Endian.little),
        newSize: data.getUint64(12, Endian.little),
        oldHash: hex(20),
        newHash: hex(52),
        controlLength: data.getUint64(84, Endian.little),
        diffLength: data.getUint64(92, Endian.little),
        extraLength: data.getUint64(100, Endian.little),
      );
    } finally {
      await raf.close();
    }
  }

  static Future<String> _sha256Of(File file) async {
    final out = _HashSink();
    final hasher = sha256.startChunkedConversion(out);
    await for (final chunk in file.openRead()) {
      hasher.add(chunk);
    }
    hasher.close();
    return out.digest!;
  }

  // ── Bytes ────────────────────────────────────────────────────────────

  static Uint8List _deflate(Uint8List bytes) =>
      Uint8List.fromList(ZLibCodec(level: 9).encode(bytes));

  static Uint8List _u64(int v) {
    final b = ByteData(8)..setUint64(0, v, Endian.little);
    return b.buffer.asUint8List();
  }

  static int _zigzag(int v) => v >= 0 ? v * 2 : -v * 2 - 1;
  static int _unzigzag(int v) => v.isEven ? v ~/ 2 : -(v + 1) ~/ 2;

  static void _varint(BytesBuilder b, int v) {
    while (v >= 0x80) {
      b.addByte((v & 0x7F) | 0x80);
      v >>= 7;
    }
    b.addByte(v);
  }
}

/// A patch that cannot be applied here: the phone falls back to the full
/// APK.
class ApkPatchException implements Exception {
  const ApkPatchException(this.message);
  final String message;
  @override
  String toString() => 'ApkPatchException: $message';
}

class _Header {
  const _Header({
    required this.oldSize,
    required this.newSize,
    required this.oldHash,
    required this.newHash,
    required this.controlLength,
    required this.diffLength,
    required this.extraLength,
  });
  final int oldSize, newSize;
  final String oldHash, newHash;
  final int controlLength, diffLength, extraLength;
}

/// Where in the old file each [_window]-byte stretch starts, for every
/// [ApkPatch._sample]th position: an open-addressed table of positions
/// keyed by a rolling hash of the stretch.
class _Index {
  _Index(this._old) : _slots = Int32List(_sizeFor(_old.length)) {
    _mask = _slots.length - 1;
    if (_old.length < ApkPatch._window) return;
    var h = hashAt(_old, 0);
    for (var p = 0;; p++) {
      if (p % ApkPatch._sample == 0) {
        final slot = _slot(h);
        if (_slots[slot] == 0) _slots[slot] = p + 1;
      }
      if (p + ApkPatch._window >= _old.length) break;
      h = roll(h, _old[p], _old[p + ApkPatch._window]);
    }
  }

  final Uint8List _old;
  final Int32List _slots;
  late final int _mask;

  static int _sizeFor(int n) {
    var size = 1024;
    while (size < (n ~/ ApkPatch._sample) * 2) {
      size <<= 1;
    }
    return size;
  }

  static const _base = 257;
  static final int _baseToWindow = () {
    var v = 1;
    for (var i = 0; i < ApkPatch._window; i++) {
      v = (v * _base) & 0xFFFFFFFF;
    }
    return v;
  }();

  static int hashAt(Uint8List b, int at) {
    var h = 0;
    for (var i = 0; i < ApkPatch._window; i++) {
      h = (h * _base + b[at + i]) & 0xFFFFFFFF;
    }
    return h;
  }

  /// The hash one byte on: [leaving] drops out, [entering] comes in.
  static int roll(int h, int leaving, int entering) =>
      (h * _base - leaving * _baseToWindow + entering) & 0xFFFFFFFF;

  int _slot(int h) => ((h * 0x9E3779B1) & 0xFFFFFFFF) >> 8 & _mask;

  /// An old position whose stretch may match, or -1. Check before trusting.
  int lookup(int h) => _slots[_slot(h)] - 1;
}

/// A growable byte buffer that does not copy on every add.
class _Bytes {
  _Bytes(int capacity) : _buf = Uint8List(math.max(capacity, 1024));
  Uint8List _buf;
  int _len = 0;

  void _grow(int need) {
    if (_len + need <= _buf.length) return;
    var size = _buf.length * 2;
    while (size < _len + need) {
      size *= 2;
    }
    _buf = Uint8List(size)..setRange(0, _len, _buf);
  }

  void add(int byte) {
    _grow(1);
    _buf[_len++] = byte;
  }

  void addRange(Uint8List from, int start, int end) {
    _grow(end - start);
    _buf.setRange(_len, _len + end - start, from, start);
    _len += end - start;
  }

  Uint8List get bytes => Uint8List.sublistView(_buf, 0, _len);
}

/// One deflated stream inside the patch, read a piece at a time: the diff
/// stream alone inflates to the size of the whole app.
class _InflatingReader {
  _InflatingReader._(this._file, this._left);

  static Future<_InflatingReader> open(File patch, int start, int length) async {
    final raf = await patch.open();
    await raf.setPosition(start);
    return _InflatingReader._(raf, length);
  }

  final RandomAccessFile _file;
  int _left;
  final _filter = RawZLibFilter.inflateFilter();
  List<int> _chunk = const [];
  int _at = 0;
  bool _ended = false;

  Future<void> _fill() async {
    while (_at >= _chunk.length) {
      final out = _filter.processed(flush: false);
      if (out != null && out.isNotEmpty) {
        _chunk = out;
        _at = 0;
        return;
      }
      if (_left == 0) {
        if (_ended) throw const ApkPatchException('patch stream ends early');
        _ended = true;
        final last = _filter.processed(end: true);
        if (last != null && last.isNotEmpty) {
          _chunk = last;
          _at = 0;
        }
        continue;
      }
      final n = math.min(_left, 64 * 1024);
      final input = await _file.read(n);
      if (input.isEmpty) throw const ApkPatchException('patch is truncated');
      _left -= input.length;
      _filter.process(input, 0, input.length);
    }
  }

  Future<int> byte() async {
    await _fill();
    return _chunk[_at++];
  }

  Future<int> varint() async {
    var v = 0, shift = 0;
    while (true) {
      final b = await byte();
      v |= (b & 0x7F) << shift;
      if (b < 0x80) return v;
      shift += 7;
      if (shift > 56) throw const ApkPatchException('bad number in patch');
    }
  }

  /// Exactly [n] bytes into the start of [into].
  Future<void> readInto(Uint8List into, int n) async {
    var got = 0;
    while (got < n) {
      await _fill();
      final take = math.min(n - got, _chunk.length - _at);
      into.setRange(got, got + take, _chunk, _at);
      _at += take;
      got += take;
    }
  }

  Future<void> close() => _file.close();
}

class _HashSink implements Sink<Digest> {
  String? digest;
  @override
  void add(Digest data) => digest = data.toString();
  @override
  void close() {}
}
