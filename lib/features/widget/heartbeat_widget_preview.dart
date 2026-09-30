import 'package:flutter/cupertino.dart';

import '../../core/widgets/app_icon.dart';
import 'heartbeat_themes.dart';

/// The heartbeat widget in miniature, as layout/heartbeat_widget.xml draws
/// it: the [theme]'s scene filling the card, "HEARTBEAT" over it and "Tap to
/// send" under it. Laid out at the widget's 180dp and scaled to whatever
/// width it is given, so Settings and the widget gallery show the real
/// proportions at their own sizes.
///
/// ⚠️ Keep the numbers in step with the XML (margins 18 and 16, text 13 and
/// 12, the button's padding and colours): this is the only look at the widget most
/// people get before they place it.
class HeartbeatWidgetPreview extends StatelessWidget {
  const HeartbeatWidgetPreview({super.key, required this.theme});

  final HeartbeatTheme theme;

  static const _title = Color(0xFFF5A5BF);
  static const _label = Color(0xFFFDF0F5);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final u = box.maxWidth / 180;
      return MediaQuery.withNoTextScaling(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20 * u),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Centre-cropped round the heart, like the widget.
              Image.asset(theme.thumbnail,
                  fit: BoxFit.cover, excludeFromSemantics: true),
              Positioned(
                top: 18 * u,
                left: 0,
                right: 0,
                child: Text(
                  'HEARTBEAT',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    color: _title,
                    fontSize: 13 * u,
                    letterSpacing: 0.32 * 13 * u,
                    height: 1.2,
                  ),
                ),
              ),
              Positioned(
                bottom: 16 * u,
                left: 0,
                right: 0,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xF5972F62), Color(0xF5782250)],
                      ),
                      border: Border.all(
                          color: const Color(0xE6E2508A), width: 1.5 * u),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x2EE24F88),
                          blurRadius: 4 * u,
                          spreadRadius: 2 * u,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(15 * u, 6 * u, 13 * u, 6 * u),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Tap to send',
                            maxLines: 1,
                            style: TextStyle(
                              color: _label,
                              fontSize: 12 * u,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(width: 5 * u),
                          AppIcon(CupertinoIcons.heart,
                              color: _label, size: 11 * u),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
