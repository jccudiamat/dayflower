"use client";

import { useEffect, useMemo, useRef } from "react";
import { Canvas, useFrame, useThree } from "@react-three/fiber";
import * as THREE from "three";
import { daylightAt, type Daylight } from "./daylight";

/* ── Quality ──────────────────────────────────────────────────────────────
 *
 * ⚠️ Decided once, from the device, then never re-read. Re-deciding on resize
 * would rebuild every buffer mid-scroll, which costs far more than the frames
 * it saves. Section 31 asks for tiers; this is the whole of them.
 */
export type Tier = "high" | "low";

export function detectTier(): Tier {
  if (typeof navigator === "undefined") return "low";
  const cores = navigator.hardwareConcurrency ?? 4;
  const coarse = matchMedia("(pointer: coarse)").matches;
  return !coarse && cores >= 8 ? "high" : "low";
}

const COUNTS: Record<Tier, { flowers: number }> = {
  high: { flowers: 420 },
  low: { flowers: 150 },
};

/* ── One flower ───────────────────────────────────────────────────────────
 *
 * Built in code because the project has no 3D assets, and a downloaded GLB
 * would be a stranger's flower rather than a Dayflower. Stem, five petals and
 * a centre, merged into one geometry so the whole meadow is a single draw.
 */
function flowerGeometry(): THREE.BufferGeometry {
  const parts: THREE.BufferGeometry[] = [];

  const stem = new THREE.CylinderGeometry(0.012, 0.02, 0.62, 4, 1);
  stem.translate(0, 0.31, 0);
  parts.push(stem);

  for (let i = 0; i < 5; i++) {
    const petal = new THREE.CircleGeometry(0.1, 6);
    petal.scale(0.62, 1, 1);
    petal.translate(0, 0.1, 0);
    petal.rotateZ((i / 5) * Math.PI * 2);
    petal.translate(0, 0.66, 0);
    // A shallow tilt, so the head reads as a cup rather than a flat sticker.
    petal.rotateX(-0.42);
    parts.push(petal);
  }

  const centre = new THREE.SphereGeometry(0.045, 6, 5);
  centre.translate(0, 0.67, 0.02);
  parts.push(centre);

  const merged = mergeGeometries(parts);
  parts.forEach((p) => p.dispose());
  return merged;
}

/** Minimal merge: three's own helper lives in an addons path we would rather not pull in. */
function mergeGeometries(list: THREE.BufferGeometry[]): THREE.BufferGeometry {
  const out = new THREE.BufferGeometry();
  let vertexCount = 0;
  let indexCount = 0;
  for (const g of list) {
    vertexCount += g.attributes.position.count;
    indexCount += g.index ? g.index.count : g.attributes.position.count;
  }
  const position = new Float32Array(vertexCount * 3);
  const normal = new Float32Array(vertexCount * 3);
  // 0 at the root, 1 at the tip. The wind shader leans by this, so the stem
  // base stays planted while the head travels.
  const sway = new Float32Array(vertexCount);
  const index = new Uint16Array(indexCount);

  let vo = 0;
  let io = 0;
  for (const g of list) {
    const pos = g.attributes.position as THREE.BufferAttribute;
    const nor = g.attributes.normal as THREE.BufferAttribute;
    for (let i = 0; i < pos.count; i++) {
      position.set([pos.getX(i), pos.getY(i), pos.getZ(i)], (vo + i) * 3);
      normal.set([nor.getX(i), nor.getY(i), nor.getZ(i)], (vo + i) * 3);
      sway[vo + i] = Math.min(1, Math.max(0, pos.getY(i) / 0.7)) ** 1.6;
    }
    if (g.index) {
      for (let i = 0; i < g.index.count; i++) index[io + i] = g.index.getX(i) + vo;
      io += g.index.count;
    } else {
      for (let i = 0; i < pos.count; i++) index[io + i] = i + vo;
      io += pos.count;
    }
    vo += pos.count;
  }

  out.setAttribute("position", new THREE.BufferAttribute(position, 3));
  out.setAttribute("normal", new THREE.BufferAttribute(normal, 3));
  out.setAttribute("sway", new THREE.BufferAttribute(sway, 1));
  out.setIndex(new THREE.BufferAttribute(index, 1));
  return out;
}

/* ── The meadow ───────────────────────────────────────────────────────────── */

// Weighted toward cream and white, with the brand pinks as accents and two
// warm yellows for lift. The brief rules out "overly pink" and a field of one
// hue reads as wallpaper; the eye needs somewhere to rest between the blooms.
const PETAL_COLOURS = [
  "#fdf4ec", "#fbe9ee", "#ffffff", "#fdf4ec",
  "#ef7fa8", "#f6a8c3", "#d96b95",
  "#f7d9a0", "#f3c6dc", "#fbe3ec",
];

function Meadow({ tier, light, pointer }: { tier: Tier; light: Daylight; pointer: React.RefObject<THREE.Vector2> }) {
  const count = COUNTS[tier].flowers;
  const mesh = useRef<THREE.InstancedMesh>(null);
  const geometry = useMemo(() => flowerGeometry(), []);
  const uniforms = useMemo(
    () => ({
      uTime: { value: 0 },
      uWind: { value: 1 },
      uPointer: { value: new THREE.Vector3(999, 0, 999) },
      uNocturnal: { value: 0 },
    }),
    [],
  );

  const { matrices, colours, phases } = useMemo(() => {
    const m = new THREE.Object3D();
    const matrices = new Float32Array(count * 16);
    const colours = new Float32Array(count * 3);
    const phases = new Float32Array(count);
    const c = new THREE.Color();
    // A fixed sequence, not Math.random: the meadow must be identical on every
    // reload, or it visibly reshuffles when the scene remounts.
    let seed = 20260919;
    const rand = () => ((seed = (seed * 1664525 + 1013904223) % 4294967296) / 4294967296);

    for (let i = 0; i < count; i++) {
      // 🔴 A forward wedge, not a ring around the origin. A ring put a third of
      // the meadow behind the camera and dropped the rest in its lap, so the
      // opening frame was three flowers the size of trees. Depth is pushed out
      // along z and the spread widens with it, which matches the frustum and
      // reads as a field receding rather than as a wall.
      const depth = rand();
      const z = 1.4 + depth * depth * 23;
      const spread = 1.6 + z * 0.62;
      m.position.set((rand() * 2 - 1) * spread, 0, z);
      m.rotation.set(0, rand() * Math.PI, 0);
      // Distant flowers stay a shade larger than true perspective would have
      // them, so the far field keeps some colour instead of dissolving.
      const s = (0.5 + rand() * 0.42) * (1 + depth * 0.5);
      m.scale.setScalar(s);
      m.updateMatrix();
      m.matrix.toArray(matrices, i * 16);
      c.set(PETAL_COLOURS[Math.floor(rand() * PETAL_COLOURS.length)]);
      colours.set([c.r, c.g, c.b], i * 3);
      phases[i] = rand() * Math.PI * 2;
    }
    return { matrices, colours, phases };
  }, [count]);

  useEffect(() => {
    if (!mesh.current) return;
    mesh.current.instanceMatrix.array.set(matrices);
    mesh.current.instanceMatrix.needsUpdate = true;
  }, [matrices]);

  useFrame((_, delta) => {
    uniforms.uTime.value += delta;
    uniforms.uNocturnal.value += (light.nocturnal - uniforms.uNocturnal.value) * Math.min(1, delta * 2);
    const p = pointer.current;
    if (p) uniforms.uPointer.value.set(p.x * 8, 0, 7 - p.y * 5);
  });

  return (
    <instancedMesh ref={mesh} args={[geometry, undefined, count]} frustumCulled={false}>
      <shaderMaterial
        uniforms={uniforms}
        side={THREE.DoubleSide}
        vertexShader={/* glsl */ `
          attribute float sway;
          attribute vec3 tint;
          attribute float phase;
          uniform float uTime;
          uniform float uWind;
          uniform vec3 uPointer;
          uniform float uNocturnal;
          varying vec3 vTint;
          varying float vShade;
          varying float vPetal;

          void main() {
            vTint = tint;
            // The merged geometry puts the stem below 0.63 and the head above
            // it, so local height alone separates the two. Cheaper than
            // carrying a second attribute for one bit of information.
            vPetal = step(0.63, position.y);
            vec4 world = instanceMatrix * vec4(position, 1.0);

            // Wind: two offset waves, so the field never pulses in unison.
            float t = uTime * 0.85 + phase;
            float gust = sin(t) * 0.6 + sin(t * 0.43 + world.x * 0.3) * 0.4;
            world.x += gust * sway * 0.16 * uWind;
            world.z += cos(t * 0.7) * sway * 0.07 * uWind;

            // Lean away from the cursor, falling off fast so only the handful
            // of flowers actually near it move.
            vec2 away = world.xz - uPointer.xz;
            float near = 1.0 - smoothstep(0.0, 2.4, length(away));
            world.xz += normalize(away + 0.001) * near * sway * 0.4;

            // Closing for the night: heads draw down toward the stem.
            world.y -= uNocturnal * sway * 0.06;

            vShade = 0.58 + sway * 0.42;
            gl_Position = projectionMatrix * viewMatrix * world;
          }
        `}
        fragmentShader={/* glsl */ `
          varying vec3 vTint;
          varying float vShade;
          varying float vPetal;
          uniform float uNocturnal;
          void main() {
            vec3 stem = vec3(0.42, 0.56, 0.38);
            vec3 base = mix(stem, vTint, vPetal);
            vec3 night = vec3(0.42, 0.46, 0.72);
            vec3 c = mix(base, base * night * 1.5, uNocturnal * 0.75);
            gl_FragColor = vec4(c * vShade, 1.0);
          }
        `}
      />
      <instancedBufferAttribute attach="geometry-attributes-tint" args={[colours, 3]} />
      <instancedBufferAttribute attach="geometry-attributes-phase" args={[phases, 1]} />
    </instancedMesh>
  );
}

/* ── Sky, ground, hills ───────────────────────────────────────────────────── */

function Backdrop({ light }: { light: Daylight }) {
  const sky = useMemo(
    () => ({ uTop: { value: new THREE.Color() }, uLow: { value: new THREE.Color() } }),
    [],
  );
  const top = useMemo(() => new THREE.Color(), []);
  const low = useMemo(() => new THREE.Color(), []);

  useFrame(() => {
    sky.uTop.value.lerp(top.set(light.skyTop), 0.08);
    sky.uLow.value.lerp(low.set(light.skyLow), 0.08);
  });

  return (
    <>
      {/* Inside-out sphere: cheaper and steadier than a full skybox. */}
      <mesh scale={[-70, 70, 70]}>
        <sphereGeometry args={[1, 24, 16]} />
        <shaderMaterial
          uniforms={sky}
          depthWrite={false}
          vertexShader={`varying float vH; void main(){ vH = normalize(position).y; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }`}
          fragmentShader={`uniform vec3 uTop; uniform vec3 uLow; varying float vH;
            void main(){ gl_FragColor = vec4(mix(uLow, uTop, smoothstep(-0.15, 0.62, vH)), 1.0); }`}
        />
      </mesh>

      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, -0.01, 0]}>
        <circleGeometry args={[60, 48]} />
        <meshStandardMaterial color={light.ground} roughness={1} />
      </mesh>

      {/* Soft hills. The fog does the atmospheric perspective for us. */}
      {[
        [-26, 46, 15, 0.34],
        [22, 54, 18, 0.3],
        [2, 70, 24, 0.26],
      ].map(([x, z, r, squash], i) => (
        // Squashed spheres, sunk below the ground line: a hemisphere reads as a
        // hill, a whole sphere reads as a ball sitting in a field.
        <mesh key={i} position={[x, -r * (1 - squash) - 1.5, z]} scale={[1.6, squash, 1]}>
          <sphereGeometry args={[r, 18, 12]} />
          <meshStandardMaterial color={light.hills} roughness={1} />
        </mesh>
      ))}
    </>
  );
}

/* ── The rig ──────────────────────────────────────────────────────────────── */

function Rig({ light, pointer, tier }: { light: Daylight; pointer: React.RefObject<THREE.Vector2>; tier: Tier }) {
  const { camera, size } = useThree();
  const sun = useRef<THREE.DirectionalLight>(null);
  const target = useRef(new THREE.Vector3(0, 1.5, 0));

  useFrame((_, delta) => {
    const p = pointer.current;
    // A very small parallax: enough that the world feels held rather than
    // printed, not enough to make anybody seasick.
    if (p) {
      target.current.x += (p.x * 0.42 - target.current.x) * Math.min(1, delta * 2.2);
      target.current.y += (1.5 + p.y * 0.2 - target.current.y) * Math.min(1, delta * 2.2);
    }
    camera.position.x += (target.current.x - camera.position.x) * Math.min(1, delta * 2.4);
    camera.position.y += (target.current.y - camera.position.y) * Math.min(1, delta * 2.4);

    // A tall screen is not a narrow wide one. Framed the same way, a phone gets
    // a band of flowers pinned between an empty sky and an empty lawn, because
    // the extra height all lands above and below the interesting part. Portrait
    // drops the horizon and looks nearer, so the meadow fills the frame the
    // copy panel is floating over.
    const portrait = Math.min(1, Math.max(0, (1.1 - size.width / size.height) / 0.7));
    camera.lookAt(0, 0.62 - portrait * 0.5, 7 - portrait * 2.6);

    if (sun.current) {
      sun.current.position.set(-9, 3 + light.sunHeight * 12, 14);
      sun.current.intensity = light.sunIntensity;
      sun.current.color.set(light.sun);
    }
  });

  return (
    <>
      <fog attach="fog" args={[light.skyLow, 16, tier === "high" ? 62 : 46]} />
      <ambientLight intensity={light.fillIntensity} color={light.fill} />
      <directionalLight ref={sun} position={[-9, 8, 14]} />
    </>
  );
}

/* ── Public entry ─────────────────────────────────────────────────────────── */

export default function Scene({ phase, tier }: { phase: number; tier: Tier }) {
  const pointer = useRef(new THREE.Vector2(0, 0));
  const light = daylightAt(phase);

  useEffect(() => {
    if (matchMedia("(pointer: coarse)").matches) return;
    const onMove = (e: PointerEvent) => {
      pointer.current.set((e.clientX / innerWidth) * 2 - 1, -((e.clientY / innerHeight) * 2 - 1));
    };
    addEventListener("pointermove", onMove, { passive: true });
    return () => removeEventListener("pointermove", onMove);
  }, []);

  return (
    <Canvas
      // ⚠️ Capped at 1.5 rather than the device's own ratio. A 3x phone screen
      // would otherwise render nine times the pixels of a 1x one, for a scene
      // that is almost entirely soft gradients where nobody can see them.
      dpr={[1, tier === "high" ? 1.5 : 1]}
      camera={{ fov: 40, position: [0, 1.5, -1.2], near: 0.1, far: 120 }}
      gl={{ antialias: tier === "high", powerPreference: "high-performance" }}
      // The world is scenery. Every control on the page is HTML above it.
      style={{ pointerEvents: "none" }}
    >
      <Rig light={light} pointer={pointer} tier={tier} />
      <Backdrop light={light} />
      <Meadow tier={tier} light={light} pointer={pointer} />
    </Canvas>
  );
}
