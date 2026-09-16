import Image from "next/image";

/**
 * Worked examples of what the two free tools actually produce.
 *
 * Both pages led with a wall of prose describing an image, which is the one
 * thing prose is worst at. These show the output instead.
 *
 * 🔴 **The people are AI-generated models, not users.** Nobody pictured here
 * made anything on Dayflower, so every example carries a caption saying so.
 * A couples site showing invented faces as if they were real customers is
 * exactly the kind of thing that erodes trust when someone works it out, and
 * the disclosure costs nothing.
 */

const MODELS = {
  cove: { src: "/models/cove.webp", alt: "A man smiling on a boat in a turquoise cove" },
  sunset: { src: "/models/sunset.webp", alt: "A woman smiling on a beach at sunset" },
} as const;

function Shot({ model, className = "" }: { model: keyof typeof MODELS; className?: string }) {
  // src and alt are passed by name rather than spread: the a11y lint rule
  // cannot see an alt that arrives through `{...props}` and warns on every
  // one of these, which trains you to ignore the rule that catches the real
  // omissions.
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
 * A finished couple strip, the thing the booth is for: two people who were
 * not in the same place, printed as though they were.
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
        An example strip. The people are AI-generated models, not Dayflower users.
      </figcaption>
    </figure>
  );
}

/**
 * A bouquet with a photo tucked into it, which is the part that makes this
 * different from sending a picture of flowers.
 */
export function ExampleBouquet() {
  return (
    <figure className="m-0 flex flex-col items-center">
      <div className="relative w-[230px]">
        <Image
          src="/flowers/wrapped_bouquet.webp"
          alt="An illustrated bouquet wrapped in paper"
          width={512}
          height={512}
          sizes="240px"
          className="h-auto w-full"
        />
        {/* Tucked in among the stems, overlapping the wrap, because that is
            where it sits in the real thing. */}
        <div
          className="absolute -bottom-3 -left-5 w-[104px] rounded-[9px] bg-[#fffdf8] p-[7px] shadow-[0_12px_28px_#1c10241f]"
          style={{ transform: "rotate(-8deg)" }}
        >
          <div className="aspect-[4/5] overflow-hidden rounded-[5px]"><Shot model="sunset" /></div>
          <p className="mt-[5px] text-center font-[family-name:var(--font-lora)] text-[9.5px] italic text-[#733952]">
            miss you
          </p>
        </div>
      </div>
      <figcaption className="mt-8 text-center text-xs leading-relaxed text-muted">
        An example bouquet with a photo tucked in. The person is an AI-generated model.
      </figcaption>
    </figure>
  );
}
