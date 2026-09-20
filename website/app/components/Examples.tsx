import Image from "next/image";

/**
 * Worked examples of what the two free tools actually produce.
 *
 * Both pages led with a wall of prose describing an image, which is the one
 * thing prose is worst at. These show the output instead.
 *
 * ⚠️ The faces are synthetic stand-ins, never a real customer and never a real
 * photograph of anybody. That fact lives here rather than in a caption on the
 * page: a caption calling your own sample fake distracts from the thing being
 * shown, and every example is visibly an example anyway.
 */

const MODELS = {
  cove: { src: "/models/cove.webp", alt: "A man smiling on a boat in a turquoise cove" },
  sunset: { src: "/models/sunset.webp", alt: "A woman smiling on a beach at sunset" },
} as const;

function Shot({ model, className = "" }: { model: keyof typeof MODELS; className?: string }) {
  // src and alt are passed by name rather than spread: the a11y lint rule
  // cannot see an alt that arrives through `{...props}` and warns on every one
  // of these, which trains you to ignore the rule that catches real omissions.
  const { src, alt } = MODELS[model];
  return (
    <Image
      src={src}
      alt={alt}
      width={720}
      height={960}
      // ⚠️ Capped well below the source. These never render wider than about
      // 180px, and letting Next serve a 720 for a 180px slot would undo the
      // point of compressing them in the first place.
      sizes="200px"
      className={`h-full w-full object-cover ${className}`}
    />
  );
}

/**
 * A finished couple strip, the thing the booth is for: two people who were not
 * in the same place, printed as though they were.
 */
export function ExampleStrip() {
  return (
    <figure className="m-0 flex flex-col items-center">
      <div className="relative">
        {/* A second strip behind, so the object reads as a physical print
            rather than a single flat image pasted on the page. */}
        <div
          aria-hidden
          className="absolute inset-0 rounded-[14px] bg-[#f3e6ec] shadow-[0_10px_30px_#1c102412]"
          style={{ transform: "rotate(5deg)" }}
        />
        <div
          className="relative w-[188px] rounded-[14px] bg-[#fffdf8] p-[10px] shadow-[0_14px_36px_#1c102421]"
          style={{ transform: "rotate(-3deg)" }}
        >
          <div className="overflow-hidden rounded-[7px]">
            <div className="aspect-[4/5]"><Shot model="cove" /></div>
          </div>
          <div className="mt-[7px] overflow-hidden rounded-[7px]">
            <div className="aspect-[4/5]"><Shot model="sunset" /></div>
          </div>
          <p className="mt-[9px] text-center font-[family-name:var(--font-lora)] text-[12px] italic text-[#733952]">
            same sun, eventually
          </p>
        </div>
      </div>
      <figcaption className="mt-7 text-center text-xs leading-relaxed text-muted">
        A couple strip, made from two photos taken a thousand miles apart.
      </figcaption>
    </figure>
  );
}

/**
 * A finished bouquet, the way it arrives.
 *
 * ⚠️ Only the flowers are an image. The heading, the note and the signature are
 * real HTML on a ground colour sampled from the artwork (#f7eef1), so the seam
 * is invisible while the words stay selectable, translatable and indexable,
 * none of which is true of text baked into a picture, on a page whose whole job
 * is ranking for "digital bouquet".
 */
export function ExampleBouquet() {
  return (
    <figure className="m-0 w-full max-w-[330px] overflow-hidden rounded-[22px] bg-[#f7eef1] shadow-[0_18px_44px_#1c10241a]">
      <p className="px-6 pt-7 text-center text-[10px] font-bold uppercase tracking-[0.13em] text-[#8a6b78]">
        A little something, just for you
      </p>
      <p className="mt-2 px-6 text-center font-[family-name:var(--font-lora)] text-[25px] italic text-[#733952]">
        For Sam
      </p>
      <Image
        src="/models/bouquet-sample.webp"
        alt="A bouquet of roses, daisies and tulips wrapped in cream paper, with a photo tucked in among the stems"
        width={720}
        height={625}
        sizes="330px"
        className="mt-1 h-auto w-full"
      />
      <div className="mx-4 rounded-[14px] bg-[#fffdf8] px-5 py-5">
        <p className="text-center font-[family-name:var(--font-lora)] text-[13px] italic leading-relaxed text-[#5d4550]">
          Thinking about you on the walk home, which is most of the walk home.
          Nothing is wrong. I just wanted you to have something today.
        </p>
        <p className="mt-4 text-center text-[11px] text-[#8a6b78]">With love, Alex 🌷</p>
      </div>
      <p className="px-6 py-5 text-center text-[9px] font-bold uppercase tracking-[0.13em] text-[#a8919b]">
        Made with love · Dayflower
      </p>
    </figure>
  );
}

/* ── Homepage tool cards ────────────────────────────────────────────────── */

/**
 * The little picture at the top of each card on the homepage.
 *
 * ⚠️ All four cards get one, not just the two that needed it. A row of four
 * where two carry a picture and two do not reads as a page that failed to load
 * rather than as a deliberate choice.
 */
export function ToolThumb({ tool }: { tool: string }) {
  if (tool === "Photo booth") {
    // Two photos side by side: the booth's couple layout, which is the one
    // thing here you cannot show with a single picture.
    return (
      <div className="home-tool-thumb">
        <div className="home-tool-strip" style={{ transform: "rotate(-2.5deg)" }}>
          <span><Shot model="cove" /></span>
          <span><Shot model="sunset" /></span>
        </div>
      </div>
    );
  }

  // cover for the photographic scenes, which crop happily; contain for a
  // cut-out object, which would lose its edges.
  const art: Record<string, { src: string; alt: string; fit: "contain" | "cover" }> = {
    // A crop of the bouquet sample further down this file, so the card
    // promises the thing the page actually delivers.
    Bouquet: { src: "/models/bouquet-thumb.webp", alt: "A bouquet of daisies, tulips and roses with a photo tucked in among the stems", fit: "cover" },
    // ⚠️ Our own illustration, not a listing photo from the catalogue. Those
    // are sellers' images: several carry burned-in shop branding and one has
    // photographs of real people in it. Fine in the catalogue, where the page
    // credits them; not fine as decoration on the homepage.
    Gifts: { src: "/bouquet/reveal-box.webp", alt: "An illustrated gift box tied with a ribbon", fit: "contain" },
    Journal: { src: "/flowers/bench_in_bloom.webp", alt: "An illustrated bench surrounded by flowers", fit: "cover" },
  };
  const a = art[tool];
  if (!a) return null;

  return (
    <div className="home-tool-thumb">
      <Image
        src={a.src}
        alt={a.alt}
        width={512}
        height={512}
        sizes="280px"
        className={`home-tool-art is-${a.fit}`}
      />
    </div>
  );
}
