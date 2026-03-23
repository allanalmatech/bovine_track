# The Design System: Editorial Agritech Documentation

## 1. Overview & Creative North Star: "The Digital Pasture"
The design system for BovineTrack departs from the rigid, grid-heavy "utility" look common in agricultural software. Our Creative North Star is **"The Digital Pasture"**—a philosophy that balances the raw, expansive utility of the field with the sophisticated precision of modern data science.

We achieve this through **Organic Brutalism**: utilizing heavy-weight editorial typography and large-scale corner radii (up to `xl: 3rem`) to create a UI that feels grounded and "thick," yet refined. By eliminating traditional borders and dividers, we allow the data to breathe, mimicking the open horizons of a ranch. The interface is not a set of boxes; it is a series of layered, tactile surfaces.

---

## 2. Color & Tonal Depth
Our palette is rooted in the "Deep Forest" primary (`#00450d`), providing an authoritative anchor against a "Soft Dew" background (`#f5fced`).

### The "No-Line" Rule
**Explicit Instruction:** Designers are prohibited from using 1px solid borders to section content. Boundaries must be defined solely through background color shifts or tonal transitions.
- To separate a header from a body, transition from `surface` to `surface-container-low`.
- To highlight a featured metric, nest a `surface-container-lowest` card within a `surface-container` section.

### Glass & Gradient Signature
To move beyond "flat" Material design, use **Glassmorphism** for floating elements (like FABs or overlaying status cards). Use a 20% opacity on the surface color with a `16px` backdrop blur.
- **The Signature Pulse:** For primary CTAs and Hero headers, use a subtle linear gradient (45°) transitioning from `primary` (#00450d) to `primary_container` (#065f18). This adds a "visual soul" and depth that static hex codes cannot achieve.

---

## 3. Typography: Editorial Authority
We pair the geometric stability of **Manrope** for display with the high-legibility of **Inter** for utility.

*   **Display & Headlines (Manrope):** These are your "Statement" tiers. Use `display-lg` (3.5rem) with tight letter-spacing (-0.02em) for hero metrics like total herd count. This conveys an "Editorial" confidence.
*   **Body & Labels (Inter):** Reserved for technical data. Use `body-md` (0.875rem) for all livestock details to ensure maximum readability in high-glare outdoor environments.
*   **Hierarchy Tip:** Always skip a weight or size in the scale to create dramatic contrast. Do not pair `title-lg` with `title-md`; pair `headline-sm` with `body-md` to ensure the hierarchy is unmistakable at a glance.

---

## 4. Elevation & Depth: The Layering Principle
We reject the standard "drop shadow" in favor of **Tonal Layering**.

*   **Stacked Surfaces:** Depth is achieved by "nesting." 
    *   Level 0: `surface` (Main Background)
    *   Level 1: `surface-container-low` (Content Sections)
    *   Level 2: `surface-container-lowest` (Interactive Cards)
*   **Ambient Shadows:** If a "floating" effect is mandatory (e.g., a FAB), use an extra-diffused shadow: `box-shadow: 0px 12px 32px rgba(23, 29, 20, 0.08)`. The shadow uses the `on_surface` color, not pure black, to mimic natural ambient light.
*   **The Ghost Border:** For high-glare accessibility, use a "Ghost Border"—the `outline_variant` token at **15% opacity**. It provides a suggestion of a container without breaking the "No-Line" rule.

---

## 5. Components

### Cards & Data Containers
*   **Styling:** Use `rounded-lg` (2rem) or `rounded-xl` (3rem) for parent containers. 
*   **Constraint:** Forbid the use of divider lines. Separate list items using `spacing-4` (1rem) of vertical whitespace or a alternating `surface-container-low` and `surface-container-lowest` backgrounds.

### Action Elements (Buttons & FABs)
*   **Primary Button:** Uses the "Signature Pulse" gradient. Corner radius must be `full` (9999px) to contrast against the softer `lg` card corners.
*   **The Extended FAB:** Use `primary_fixed` (#a3f69c) for the FAB to ensure it "pops" against the deep green primary brand elements.

### Status Indicators
*   **Active/Healthy:** `primary_container` (#065f18) text on `primary_fixed` (#a3f69c) background.
*   **Alert/Danger:** `on_error_container` (#93000a) text on `error_container` (#ffdad6) background.
*   **Warning:** `on_tertiary_fixed_variant` (#7a2949) text on `tertiary_fixed` (#ffd9e2).

### Specialized Agritech Components
*   **Health Chronometers:** Use semi-circular progress rings with `surface_variant` as the track and `primary` as the indicator.
*   **Livestock Tags:** Small, high-contrast chips using `secondary_container` (#cfe6f2) to denote categories like "Bred," "Vaccinated," or "Pasture A."

---

## 6. Do’s and Don’ts

### Do:
*   **Do** use `spacing-8` (2rem) as your default "breathing room" between major sections.
*   **Do** use `surface_bright` for interactive elements that need to feel "lifted" in direct sunlight.
*   **Do** leverage `headline-lg` for single, impactful numbers.

### Don’t:
*   **Don’t** use 1px dividers. If you feel the need for a line, use a 4px `surface-variant` block or simply more whitespace.
*   **Don’t** use pure black (#000000) for text. Always use `on_surface` (#171d14) to maintain the organic, premium feel.
*   **Don’t** use shadows on cards that are resting on the background. Let the color shift do the work.