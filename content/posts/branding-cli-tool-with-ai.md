---
title: "Branding a CLI Tool in 4 Days: Mascot, Screencasts, and Visual Identity with AI"
date: 2026-02-24
draft: false
tags: ["branding", "mascot", "ai-art", "cli", "terminal", "tui", "open-source", "design", "developer-tools", "shelfctl", "bubble-tea", "vhs", "screencasts", "github", "readme", "image-generation", "character-design", "go", "golang", "marketing", "developer-experience", "visual-identity"]
categories: ["tools", "design"]
description: "How I built a cohesive visual identity for a CLI tool using AI image generation - from locking down a character spec to creating consistent poses, screencasts with VHS, and a terminal theme that ties everything together."
summary: "Most CLI tools ship with no visual identity beyond a help screen. Here's how I used AI image generation to create Shelby, a consistent mascot with a locked-down spec, and built a complete brand system - poses, screencasts, color palette, terminal theme - for shelfctl in 4 days."
---

Most CLI tools look like this to the outside world: a help screen, a README with code blocks, and maybe a screenshot. The branding is the tool name and whatever font GitHub renders your markdown in.

That's fine for internal utilities. But if you want someone to stop scrolling past your repo, you need more than a feature list. You need a visual identity that makes people pause.

This is the story of how I built a complete brand system for [shelfctl](https://github.com/blackwell-systems/shelfctl) - a terminal-based library manager - in 4 days, alongside the application itself. The mascot, the color palette, the screencasts, the README flow, the terminal theme for screenshots. All of it reinforced by a single design spec and built with AI image generation.

## What We're Building Toward

Before the process, here's where it ended up:

![Shelby the Shelf mascot](https://github.com/blackwell-systems/shelfctl/raw/main/assets/shelby-padded.png)

This is Shelby. A bookshelf wearing a terminal cap - because the tool manages book libraries from the terminal. The design is intentional at every level: the warm wood body, the teal-and-orange color split matching the wordmark, the chunky cartoon proportions that read well at small sizes in a README.

Shelby appears in 6 different poses throughout the README, each placed at a contextual breakpoint in the document. The mascot isn't decoration - it's navigation.

But getting here took iteration. Lots of it.

## Why Brand a CLI Tool at All

Open source projects compete for attention. Not just against other tools that solve the same problem, but against every repo a developer scrolls past in a day. GitHub's explore page, Hacker News, Reddit, Twitter - every context where your project shows up, it's surrounded by other projects.

Most CLI tools present identically: a name, a one-line description, and a wall of markdown. There's nothing wrong with that if your tool is already established or if you're building for a captive audience. But if you're launching something new and want people to actually stop and look, visual identity is the differentiator.

This isn't about making things pretty for the sake of it. It's about:

- **Recognition.** If someone sees Shelby on Twitter and then encounters the README on GitHub, they connect the two instantly.
- **Professionalism signal.** A cohesive visual identity signals that someone cares about the project enough to invest beyond just code.
- **README scannability.** A 450-line README with only code blocks is a wall. The same README with contextual mascot images becomes scannable sections.
- **Shareability.** People share things that look interesting. A screenshot of a TUI with a cute mascot gets shared. A help screen doesn't.

The investment is small. The return is disproportionate.

## Starting Point: The Name and the Color Split

The name `shelfctl` gave me two natural halves: `shelf` (warm, physical, books) and `ctl` (cool, technical, terminal). That tension between physical library and digital tool became the entire visual language.

I split it into two brand colors:

- **shelf**: `#fb6820` - warm red-orange
- **ctl**: `#1b8487` - teal

These two colors drive everything: the TUI theme, the mascot's cap, the wordmark, the mermaid diagrams in documentation, the terminal theme used for screenshots. When you see orange, you're in "library" territory. When you see teal, you're in "tool" territory. The application's UI uses both throughout.

{{< callout type="info" >}}
Picking two colors instead of a full palette was deliberate. Two colors are easy to remember, easy to apply consistently, and hard to get wrong. A 6-color palette creates decisions. Two colors create a system.
{{< /callout >}}

### How the Colors Propagate

Once you have two brand colors, the question is where they show up. For shelfctl:

**In the TUI itself:**
- Teal (#1b8487, #2ecfd4) is the primary UI color - borders, dividers, focused elements
- Orange (#fb6820) is the highlight color - active selections, the hub menu icon, status indicators
- The user sees these colors every time they run the tool

**In the wordmark:**
- `shelf` rendered in orange, `ctl` rendered in teal
- Appears in architecture diagrams and promotional images

**In the HTML index viewer:**
- `shelfctl index` generates a static HTML page for browsing your library in a browser
- The same brand colors appear, but in monochrome variants - muted teal borders, desaturated orange highlights
- The full-saturation colors that work in a terminal would be harsh in a browser context, so the HTML uses toned-down versions of the same hues
- The result still reads as "shelfctl" without looking like a terminal screenshot pasted into a web page

**In documentation:**
- Mermaid diagram colors use the dark variants of these hues
- The blog uses a complementary dark palette that doesn't clash

**In the terminal theme:**
- Chosen specifically to not use teal or orange as syntax colors
- Dark background lets the TUI's own colors be the star

One decision (two colors) creates consistency across every surface the project touches. No design system needed. No style guide meeting. Just: is it warm? Orange. Is it technical? Teal.

## The First Mascot Attempts

The initial concept was simple: "a bookshelf character." I started with broad prompts and got back exactly what you'd expect - generic cartoon bookshelves with pasted-on faces, inconsistent proportions, and no personality.

The problems with early iterations:

- **Proportions shifted between generations.** One image would be tall and narrow, the next squat and wide. There was no consistent silhouette.
- **The face kept moving.** Sometimes eyes were above the shelf opening, sometimes below. Sometimes there was a separate panel for the face.
- **Material inconsistency.** Some generations looked like painted wood, others like plastic, others like a 3D render.
- **The terminal element was an afterthought.** When I asked for "a terminal on top," I got a literal monitor sitting on the bookshelf. That's not a mascot, it's furniture.

The lesson: broad prompts produce broad results. You can't iterate your way to consistency without a spec.

### The Model Matters

Before settling on a workflow, I tried three different image generation models: Google Gemini, GitHub Copilot's image generation, and GPT 5.2.

Gemini and Copilot produced awful results. The proportions were always wrong - too tall, too narrow, nothing like the squat compact shape in the spec. The terminal cap kept rendering as a baseball hat. Both models insisted on adding black rings or bands around the bottom of the body even though the spec explicitly says "no black base band, no belt-like stripe." I gave them visual reference images alongside the text spec and they still couldn't follow either one. The outputs weren't broken in an interesting way - they just couldn't adhere to a spec.

GPT 5.2 was the only model that could take a detailed character spec and produce results consistent enough across multiple generations that the outputs looked like the same character. Not every generation was usable - the hit rate was maybe 60-70% with the spec - but the successful ones were consistent with each other.

This isn't a permanent recommendation. Models improve fast. But as of early 2026, if you're trying to create a consistent character across multiple poses, the model choice is a real constraint, not just a preference.

## Writing the Character Spec

After about 15-20 failed generations, I stopped generating and started writing. The result was a document I call the Canonical Shelby Specification - a detailed character sheet that locks down every visual decision.

This was the turning point. Before the spec, I was playing slot machines with prompts, hoping for a good result. After the spec, I was manufacturing a character with known tolerances.

The spec is 183 lines. Here's what it covers and why each section exists:

### Silhouette and Proportions

```
- Width is 1.4-1.6x height (compact, grounded)
- Generously rounded corners (pill-like curvature)
- Low center of gravity
- Thick, consistent outline weight
```

Without explicit proportions, models default to human-like ratios. Shelby is a squat block, not a tall figure. The width-to-height ratio is the single most important number in the spec - get this wrong and the character doesn't read as the same character.

### Material

```
- Warm golden wood with vertical grain lines
- Vector-clean but dimensional shading
- Clear highlight zone near upper third, shadow pooling near bottom
- No painterly texture, no hyper-3D realism
```

"Wood texture" means wildly different things to different models. Some generate photorealistic oak, others generate cartoon planks. The spec locks it down: warm golden, vertical grain, vector-clean shading. This eliminates an entire category of unusable outputs.

### The Shelf Opening

```
- Horizontal cutout in upper third of body
- Darker brown interior with inset shading for depth
- Books are bright, simple rectangles (blue, red, yellow, green)
- Books sit flush, never wrapped, never overly textured
```

The books in the shelf opening are the character's most distinctive feature. Without constraints, models add covers, spines, titles, leather textures. The spec says: bright simple rectangles. This keeps the books readable at small sizes and prevents them from visually competing with the face.

### Face Placement (Non-Negotiable)

```
- Located in the lower half, entirely below the shelf opening
- Large glossy black circle eyes with high reflection shine
- Small curved smile, centered between eyes
- Circular symmetrical cheeks in soft red-orange
- Face lives directly on wood surface - no framing, no inset panel
```

I marked this section "non-negotiable" in the spec because it was the most common failure mode. Models want to put faces in the center of objects, which for a bookshelf means right in the shelf opening. The face must be below the shelf. This is checked first on every generation.

The "no framing, no inset panel" rule came from a specific failure: several generations created a darker panel around the face area, like a TV screen embedded in the wood. That's not Shelby - Shelby's face floats directly on the wood surface.

### The Terminal Cap

```
- Dark charcoal/navy
- Slight forward lip
- Green > arrow with small horizontal dash
- Not a hat - it's a terminal emerging from the head
- Must not overpower body proportions
```

The phrasing "not a hat" is in the spec because models kept generating baseball caps, beanies, and top hats. The terminal cap is a dark rectangular form with a prompt symbol - it should look like the top of a terminal window, not headwear. Including "not a hat" in the spec reduced this failure mode significantly.

### The Exclusion List

```
- No black base band or belt-like stripe
- No waist seam
- No hyper-3D realism
- No textured wood carving
- No painterly brush strokes
- No heavy floor stage
- No exaggerated 3D perspective distortion
```

This section was built entirely from failures. Every item represents something a model generated that looked wrong. The black base band was the most persistent - models love adding a dark stripe across the bottom of characters, and even with the exclusion in the spec, it still appears in about 30% of generations.

{{< callout type="info" >}}
The spec document lives in the repository at `assets/shelby-spec.md`. It's versioned alongside the code. When I need a new pose, I paste the spec into the generation prompt and describe the pose. The spec is the anchor - the pose is the variable.
{{< /callout >}}

### Spec Versioning

The spec is currently at v1.1. The original v1.0 was written after the first round of failures. v1.1 added:

- Clarified bottom edge behavior (the "this is curvature shading, not a band" note)
- Added the "form personality notes" section (solid, compact, slightly squishy, warm)
- Refined the cap description to explicitly say "not actually a hat"

Each revision came from a batch of generations that revealed an ambiguity. If two generations interpret a spec line differently, the spec needs to be more precise. The spec is a living document, not a one-time artifact.

## The Iteration Loop

With the spec in hand, the generation process changed completely. Instead of "make me a bookshelf character," the prompt became:

1. Paste the full character spec
2. Describe the specific pose or action
3. Specify the background (always alpha/transparent)
4. Generate, evaluate against spec, iterate

**What "evaluate against spec" means in practice:**

Each generation gets checked against a mental checklist derived from the spec's non-negotiable traits:

1. Face below shelf opening? (reject if no)
2. Bottom edge is gradient shading, not a black band? (reject if band)
3. Terminal cap proportional to body? (reject if oversized)
4. Limbs chunky and rounded? (reject if spindly)
5. Width-to-height ratio roughly 1.4-1.6x? (reject if too tall)
6. Wood material is vector-clean, not painterly? (reject if textured)

If any of those fail, the image gets rejected regardless of how "good" it looks overall. Consistency matters more than any individual generation looking nice.

**Common failure modes even with the spec:**

- The bottom edge keeps trying to become a black band. AI models love adding a dark stripe across the bottom of characters. The spec explicitly calls this out, but it still happens in maybe 30% of generations.
- Proportions drift toward tall and narrow. Shelby should be squat and compact. Without the width-to-height ratio in the spec, models default to human proportions.
- The terminal cap grows too large. Models tend to make headwear prominent. The spec says "must not overpower body proportions" specifically because of this.
- Books in the shelf opening get overly detailed. The spec says "simple rectangles" but models sometimes add covers, titles, or textures.
- The cheeks disappear or change color. Small detail, but important for Shelby's personality.

On average, getting a usable pose takes 3-5 generation attempts with the spec. Without the spec, I never got a usable result.

### Getting the Transparency Right

A detail that cost more time than expected: the transparency layer. AI-generated images almost always come back with a white or colored background, even when you specify "transparent background" or "alpha channel" in the prompt. Some models add a faint off-white halo around the character. Others produce a technically transparent PNG but with semi-opaque pixels around the edges that create a visible fringe when placed on a dark background.

This matters because the mascot images appear on GitHub's README renderer, which switches between light and dark mode. An image with a white fringe looks fine on white backgrounds and terrible on dark ones. The fix is post-processing: clean up the alpha channel so the character composites cleanly on any background.

This is where ImageMagick earned its keep. Rather than opening each image in a GUI editor, I used ImageMagick directly in the terminal for quick edits:

```bash
# Remove white background and create clean alpha
convert shelby.png -fuzz 10% -transparent white shelby-clean.png

# Trim excess transparent padding
convert shelby-clean.png -trim +repage shelby-trimmed.png

# Add consistent padding back
convert shelby-trimmed.png -gravity center -extent 800x800 shelby-padded.png

# Quick resize for different contexts
convert shelby-padded.png -resize 400x shelby-small.png
```

The `-fuzz` flag is critical - it controls how aggressively ImageMagick matches "near-white" pixels. Too low and you get a halo. Too high and you eat into the character's lighter areas (the wood grain highlights, the eye reflections). 10% was the sweet spot for Shelby's warm wood tones.

Doing this in the terminal instead of a GUI editor meant the operations were repeatable. When a new pose came out of the generator, the same sequence of commands produced a consistent result: clean alpha, trimmed, padded, sized. No manual selection tools, no eyeballing the cleanup. The entire post-processing pipeline for a new image took about 30 seconds.

## Creating Specific Poses

Once the base character is locked down, each pose is a variation on the same prompt structure:

**Prompt pattern:**
```
[Full character spec]

Pose: [specific description]
Background: transparent/alpha
Style: consistent with spec
```

Here's what went into each of the poses used in the README:

### Hero Shelby (Magnifying Glass)

The hero image needed to work at multiple sizes - full-width in the README header and small in social media previews. The magnifying glass gives Shelby something to do (examining, searching - relevant to a library tool) and creates an asymmetric silhouette that's more interesting than a static standing pose.

This was the first pose generated after the spec was written, and it became the reference image for all subsequent generations. When evaluating later poses, I'd compare them against this one to check consistency.

### Installing Shelby (At a Computer)

This pose shows Shelby sitting at a desk with a computer. It introduces the install section of the README, connecting the character to the action the reader is about to take. Getting the computer to look right without overwhelming the character took a few attempts - the first generations made the computer too detailed and realistic against the cartoon character.

### Commands Shelby (Kneeling, Examining)

A lower pose with the magnifying glass pointed downward, as if examining the command table that follows. This creates a visual flow: the character looks down, your eye follows to the table below. It's a small compositional trick, but it works for guiding reading direction.

![Shelby examining with magnifying glass](https://github.com/blackwell-systems/shelfctl/raw/main/assets/shelby2.png)

### Support Shelby (Call to Action)

The "Enjoying shelfctl?" image is the most marketing-forward pose. This one needed to feel warm and inviting without being cloying. The text is baked into the image rather than being a markdown header, which means it renders consistently across GitHub's various markdown contexts (repo page, mobile, dark mode).

This image doubles as a call to action - a visual nudge toward starring the repo. Most repos bury the star ask in a text line that people scroll past. Wrapping it in a warm mascot image makes the ask feel less transactional and more like a natural part of the README's flow.

![Enjoying shelfctl?](https://github.com/blackwell-systems/shelfctl/raw/main/assets/enjoying.png)

### Faces Strip (Footer)

Multiple Shelby expressions in a horizontal strip. This was generated as a single image showing different facial expressions (happy, surprised, thinking, winking). It works as a footer because it's visually dense but doesn't demand attention - you notice it if you scroll to the bottom, but it doesn't interrupt the document flow.

## Extended Lore: Beyond the Mascot

Once the main character is established, there's room to have fun with the world around it. Not everything needs to be the mascot doing a pose. Some of the most effective visual assets in the README aren't Shelby at all - they're extensions of the visual universe.

### Bookshelf Illustrations

The README includes shelf-themed architecture diagrams (shelf.png, shelf2.png, shelf3.png) that illustrate how shelfctl organizes data. These were generated with the same color palette but a different style - more infographic, less character. They show the relationship between repos, releases, and catalog files, the storage model, and the feature set.

But I went further than dry diagrams. Some of the bookshelf illustrations have personality of their own - books with little faces on them, leaning against each other, looking cheerful on their shelves. This isn't random whimsy. It extends the idea that this is a world where books and shelves have character. Shelby is the main character, but the books are the supporting cast.

These small touches do something important: they make the documentation feel alive. A shelf diagram with faceless rectangles communicates information. The same diagram with books that have tiny expressions communicates information *and* personality. The reader's reaction shifts from "I understand the architecture" to "I understand the architecture and I like this project."

### The Brand Universe

This is what I think of as extended lore. The mascot is the anchor, but the visual world around the mascot creates depth. A project with one character image feels like a logo. A project with a character, themed diagrams, expressive props, and contextual illustrations feels like a universe someone built with care.

The effort for each additional piece is small once the spec and color palette exist. Generate a bookshelf with the same warm wood tones and bright book colors. Add faces to the books. Create a cozy reading scene. Each one takes a few minutes and adds another moment of delight in the documentation.

### Release Announcements

Another place the mascot earns its keep: version releases. Instead of a plain changelog or a GitHub Release with a wall of bullet points, Shelby announces new versions. A quick pose generated from the spec - Shelby holding a sign, Shelby celebrating, Shelby presenting - turns a routine release into something people actually notice in their feed.

This works because GitHub Releases support markdown with images. A release that opens with a character image and then lists changes gets more visual weight in notifications and feeds than one that's just text. It's the same information, but the presentation creates a moment of recognition for anyone who's seen the mascot before.

The generation cost is trivial once the spec exists. Describe a celebratory pose, paste the spec, pick the best result, drop it into the release notes. Five minutes of work that makes every release feel like an event rather than a version bump.

![Shelby announcing v0.1.0](https://github.com/blackwell-systems/shelfctl/raw/main/assets/shelby_v010.png)

The key to all of this is restraint. The diagrams use the orange/teal palette and the warm-wood-and-books aesthetic but don't include Shelby directly. The books get faces but the shelves don't. Shelby announces releases but doesn't appear in every commit message. Extended lore creates depth without overexposure - the mascot stays special because it's not everywhere.

## VHS for Screencasts

Static screenshots don't show a TUI's actual flow. You need movement. But screen recordings are heavy, hard to keep updated, and often end up blurry or poorly framed.

[VHS](https://github.com/charmbracelet/vhs) solves this. It's a tool from the Charm team (same people behind Bubble Tea) that lets you script terminal recordings as `.tape` files:

```
Output tui_demo.gif

Set Shell "zsh"
Set FontSize 14
Set FontFamily "MesloLGS NF"
Set Width 1200
Set Height 800
Set Padding 20
Set BorderRadius 8
Set WindowBar Colorful

Type "shelfctl"
Enter
Sleep 4000ms

# Browse the library
Enter
Sleep 1500ms

Down
Sleep 500ms
Down
Sleep 500ms
```

This is declarative. The recording is reproducible. When the UI changes, I update the tape file and re-run it. No screen recording software, no manual timing, no post-editing.

### Why VHS Over Screen Recording

Traditional screen recording has problems for documentation:

- **Non-reproducible.** Record it once, and when the UI changes you have to record again manually. Timing, mouse movements, and framing are all different each time.
- **Resolution inconsistency.** Your terminal might be at 2x retina, the recording might compress differently, GitHub might rescale the GIF.
- **Editing friction.** Cut a bad take, speed up a slow section, trim the beginning - all of this requires video editing software.

VHS eliminates all of this:

- **Reproducible.** Same tape, same output, every time. CI could regenerate the GIF on every release if you wanted.
- **Versionable.** The tape file is 141 lines of text. It goes in git. You can diff it, review it in PRs, and see exactly what changed.
- **Configurable.** Font, size, padding, border radius, window chrome - all specified in the tape file. The output looks exactly the same on any machine that runs it.
- **Commentable.** The tape file supports comments. Each section of the demo is annotated with what it's showing:

```
# -- 4. Multi-select picker: select 5 books --
Space
Sleep 400ms
Down
Sleep 300ms
Space
Sleep 400ms
```

### The Demo Script

The tape file for shelfctl's demo GIF walks through the entire TUI in 141 lines:

1. **Cache clear** - Remove a cached book to demonstrate the download flow
2. **Hub launch** - Show the main menu with all navigation options
3. **Browse** - Navigate the book list, download a book, switch to details tab, search with live filter
4. **Edit workflow** - Open multi-select picker, select 5 books with spacebar
5. **Carousel** - Navigate between selected books as cards (peeking layout)
6. **Edit form** - Drop into the metadata form, navigate fields
7. **Return to hub** - Clean exit back to the main menu

The timing is deliberate. Sleeps between actions are tuned so the GIF reads naturally - long enough to see what happened, short enough to not bore. The total recording is about 45 seconds, which is the sweet spot for a README GIF (long enough to show the tool, short enough that people watch the whole thing).

{{< callout type="info" >}}
VHS outputs GIF, WebM, or MP4. For READMEs, GIF works because GitHub renders it inline. For blog posts, WebM would be smaller but GIF has better compatibility. The tape file stays the same regardless of output format.
{{< /callout >}}

### VHS Configuration as Brand

The VHS settings themselves are part of the brand system:

```
Set FontFamily "MesloLGS NF"   # Nerd Font for Unicode glyphs
Set Width 1200                   # Wide enough for the TUI layout
Set Height 800                   # Tall enough for the hub menu
Set Padding 20                   # Breathing room around content
Set BorderRadius 8               # Rounded corners (modern look)
Set WindowBar Colorful           # macOS-style traffic lights
```

These settings produce a specific visual result that matches the screenshots, the blog images, and the overall brand aesthetic. If someone else contributes a VHS tape for a different feature, these settings ensure it looks like it belongs.

## The Terminal Theme

This is an easy detail to overlook. You've got a beautiful mascot, a cohesive color palette, a scripted screencast - and then you take a screenshot in the default terminal theme with a white background and Courier font.

The terminal theme is part of the brand. For shelfctl's screenshots and screencasts, I chose a theme that:

- Has a dark background that doesn't compete with the teal/orange UI colors
- Doesn't use teal or orange as syntax highlighting colors (would clash with the TUI)
- Has enough contrast for text readability in compressed screenshots
- Looks professional rather than flashy

### Theme Selection Criteria

Not every popular theme works. Solarized uses teal as a primary color - that would clash directly with shelfctl's teal UI elements. Gruvbox uses orange heavily - same problem. You need a theme where your brand colors are the star, not the theme's colors.

Good choices for a teal/orange TUI:

- **Catppuccin Mocha** - soft dark background (#1e1e2e), pastel accents
- **Tokyo Night** - deep blue-black, muted colors
- **Dracula** - purple-tinted dark, warm enough for orange to pop

The font matters too. MesloLGS NF (Nerd Font patched) renders the Unicode characters that Bubble Tea uses for borders, checkboxes, and indicators. A font without those glyphs would show boxes or question marks in screenshots. The font choice isn't aesthetic - it's functional.

### Screenshot Tools

For static screenshots (not GIFs), [Freeze](https://github.com/charmbracelet/freeze) from the Charm team produces clean terminal images with configurable padding, borders, and shadows. It's the screenshot equivalent of VHS - consistent, reproducible, and configured once.

These aren't creative decisions. They're consistency decisions. The terminal theme, the font, the window padding, the border radius in VHS - all of it is specified once and reused everywhere.

## The Wordmark

The shelfctl wordmark splits the name visually: `shelf` in orange (#fb6820), `ctl` in teal (#1b8487). This reinforces the warm/cool, physical/digital split that runs through the entire brand.

The wordmark appears in the architecture diagram images (the shelf illustrations) rather than as a standalone logo. It's integrated into context rather than slapped on top.

The wordmark was also generated with AI, with the same iterative process: specify the colors, the font feel (clean, modern, slightly rounded), and the split point. It took fewer iterations than the mascot because typography is more constrained - there are fewer ways to get a two-color text treatment wrong.

## Poses as README Navigation

The README for shelfctl is long - around 450 lines. That's at the upper end of what I'd normally recommend (I [wrote about README discipline]({{< ref "readme-as-landing-page" >}}) previously). But the content needs to be there: installation, authentication, quick start, commands, configuration, documentation links.

The challenge: how do you make a 450-line README not feel like a 450-line README?

### The Wall of Text Problem

Without visual breaks, a long README is a single scrollable column of markdown. Code blocks provide some visual texture, but they all look the same. Headers create structure but they're easy to scroll past. Tables help but they're dense.

Mascot images solve this by creating unmistakable section dividers that your eye catches while scrolling. Each image is a "you are here" marker.

### Contextual Placement

Shelby images break the wall of text into scannable sections:

1. **Hero Shelby** (top) - Magnifying glass pose, introduces the mascot and the project
2. **Architecture diagram** - Shelf-themed illustration showing the storage model
3. **Features diagram** - Different shelf illustration for the features section
4. **Installing Shelby** - Sitting at a computer, placed right before the install section
5. **Commands Shelby** - Kneeling with magnifying glass, examining the command table below
6. **Support Shelby** - "Enjoying shelfctl?" call-to-action image
7. **Faces strip** - Multiple Shelby expressions as a footer/sign-off

Each pose is contextual. Shelby isn't randomly scattered - the pose relates to the section it introduces. The magnifying glass appears when Shelby is "examining" something (commands, details). The computer pose appears at the install section. The examining-downward pose appears above a table.

This makes the README feel curated rather than decorated. The images aren't filler - they're wayfinding.

### Image Sizing in Markdown

GitHub's markdown renderer handles image sizing inconsistently. Some images render too large, others too small. The README uses explicit width attributes on the `<img>` tags:

```html
<p align="center">
  <img src="assets/shelby-padded.png" alt="Shelby" width="600">
</p>
```

Each image has a width chosen to fit its context:
- Full-width diagrams: `width="800"`
- Character poses: `width="400"` to `width="600"`
- Small icons: no width (natural size)

This ensures consistent sizing across desktop and mobile GitHub views.

### The Social Preview Image

One thing people consistently forget: when someone shares your GitHub repo link on Twitter, Slack, Discord, or anywhere else that unfurls URLs, GitHub shows a social preview image. If you haven't set one, the default is a generic card with your repo name, description, and your GitHub avatar. It looks like every other repo link ever shared.

You set this in the repo's Settings > General > Social preview. Upload a 1280x640 image and that's what appears in every link unfurl, every social share, every Slack paste. It's the single highest-visibility brand surface outside the README itself, and it takes 30 seconds to configure.

For shelfctl, the social preview is deliberately *not* the hero pose. It's Shelby seen from behind, reaching up to place a book on a shelf (or pull one down - you can't quite tell). You don't see the face. You don't see the full character. Just a warm wooden figure interacting with books on a shelf.

![Social preview - Shelby from behind](https://github.com/blackwell-systems/shelfctl/raw/main/assets/shelby3.png)

This is intentional. The social preview is often someone's very first contact with the project - a link unfurled in Slack, a card in a tweet. Showing the full mascot head-on would be the obvious choice, but showing the character from behind creates something more interesting: mystery. "What is this character? Why is it shelving a book? What's this project about?" That tension drives clicks in a way that a front-facing mascot portrait doesn't. The viewer has to visit the repo to meet the character properly.

It's a subtle introduction rather than a full reveal. The README hero image is the payoff - when they click through, they see the full Shelby with the magnifying glass, face and all. The social preview is the hook. The README is the landing.

If you've spent time on a mascot or visual identity and haven't set the social preview, you're leaving the highest-leverage placement empty. Do it before you share the repo anywhere.

## Brand Asset Licensing

One detail that's easy to overlook: licensing. The code is MIT licensed, but the mascot and brand assets need different treatment.

shelfctl's `assets/LICENSE` file allows redistribution of unmodified brand assets with shelfctl, but doesn't license them for reuse in other projects. This means:

- Forks can include Shelby (they ship shelfctl)
- Other projects can't use Shelby as their mascot
- Blog posts and articles can include Shelby images when discussing shelfctl

This is a standard approach for open source projects with brand identity. The code is free. The brand is protected. Both are clearly stated in the repo.

## What Made This Work in 4 Days

Building the application and the brand simultaneously isn't the typical approach. Usually the tool ships first, branding comes later (or never). Here's why doing them together worked:

**The spec was written early.** Once I had a concept that worked (bookshelf + terminal cap), I stopped generating and wrote the spec. Every subsequent image was generated from the spec, not from scratch. This eliminated the "start over" problem.

**Poses were generated as needed, not in bulk.** I didn't create 20 Shelby images and then figure out where to put them. I wrote a section of the README, identified where a visual break was needed, then generated a pose that fit that context. Content drove the art, not the other way around.

**The color palette was decided once.** Orange and teal were chosen on day 1 and never changed. The TUI was built with those colors. The mascot uses those colors. The terminal theme was chosen to complement those colors. One decision propagated everywhere.

**VHS made screencasts cheap.** Without VHS, I'd have spent hours doing screen recordings, trimming, re-recording when the UI changed. With VHS, the tape file took 20 minutes to write and generates a perfect GIF in seconds. When I changed the TUI, I updated the tape and re-ran it.

**AI made the mascot possible.** Without AI image generation, I'd either commission an artist (days to weeks of lead time, hundreds of dollars for multiple poses) or ship without a mascot. AI compressed the timeline from weeks to hours. The spec is what made the AI output usable.

## The Brand System

Putting it all together, here's what "branding a CLI tool" actually means:

| Element | Decision | Propagation |
|---------|----------|-------------|
| Name split | shelf (warm) / ctl (cool) | Wordmark, color palette, UI theme |
| Brand colors | #fb6820 orange, #1b8487 teal | TUI, mascot, diagrams, wordmark |
| Mascot | Shelby (bookshelf + terminal cap) | README poses, blog footer, social |
| Character spec | 183-line canonical document | All future image generation |
| Terminal theme | Dark, non-competing with brand colors | All screenshots and screencasts |
| Font | MesloLGS NF | All terminal output |
| Screencast tool | VHS (.tape files) | Reproducible, versionable demos |
| README layout | Mascot poses as section dividers | Scannable, contextual navigation |
| Asset licensing | MIT code, protected brand | Forks include brand, others don't reuse |

{{< mermaid >}}
flowchart TB
    subgraph foundation["Foundation"]
        NAME["Name: shelfctl"]
        COLORS["Two Colors<br/>#fb6820 + #1b8487"]
        NAME --> COLORS
    end

    subgraph assets["Generated Assets"]
        SPEC["Character Spec<br/>183 lines"]
        MASCOT["Mascot Poses<br/>7 contextual images"]
        WORD["Wordmark<br/>shelf + ctl split"]
        DIAGRAMS["Architecture Diagrams<br/>shelf-themed infographics"]
        SPEC --> MASCOT
        COLORS --> WORD
        COLORS --> DIAGRAMS
    end

    subgraph output["Surfaces"]
        TUI["TUI Theme<br/>teal borders, orange highlights"]
        README["README<br/>poses as section dividers"]
        SCREEN["Screenshots<br/>themed terminal"]
        VHS_OUT["Screencasts<br/>VHS tape files"]
        BLOG["Blog & Social<br/>consistent imagery"]
    end

    COLORS --> TUI
    MASCOT --> README
    MASCOT --> BLOG
    COLORS --> SCREEN
    COLORS --> VHS_OUT

    style foundation fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style assets fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style output fill:#4C4538,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

None of these elements are expensive. The mascot was generated with AI. The screencasts are scripted text files. The color palette is two hex values. The terminal theme is a settings toggle.

The expense is *coherence* - making sure every element reinforces every other element. That's what the spec provides. Without it, you have a collection of assets. With it, you have a brand.

## Reproducing This for Your Project

If you want to do something similar:

**1. Start with your name.** What natural tensions or visual concepts does it suggest? For shelfctl, it was physical (shelf) vs digital (ctl). For your tool, it might be speed vs reliability, simplicity vs power, local vs distributed. Find the duality and make it visual.

**2. Pick two colors.** Not five. Not a palette generator. Two colors that represent the tension in your name or concept. Use them everywhere. Two colors create a system. Six colors create decisions.

**3. Write a character spec before generating.** Spend 30 minutes describing proportions, materials, face placement, and explicit "don't do this" rules. This document will save you hours of iteration. Version it. Update it when you find ambiguities.

**4. Generate against the spec, not from scratch.** Every prompt includes the full spec. The pose is the only variable. Reject anything that violates the spec, regardless of how good it looks. Your rejection criteria should be a checklist, not a feeling.

**5. Try multiple models.** As of early 2026, capability varies significantly. What one model can't do, another might handle easily. Test with your actual spec, not with simple prompts.

**6. Place mascot images contextually.** Don't scatter them randomly. Each image should relate to the content around it. The mascot is navigation, not decoration. If you can't explain why a particular pose appears at a particular location, it shouldn't be there.

**7. Script your screencasts.** Use VHS or similar tools. Declarative recordings are reproducible, versionable, and cheap to update. Store the tape files in your repo alongside the code.

**8. Choose a terminal theme that doesn't fight your brand.** Check that the theme's accent colors don't clash with your UI colors. Test by taking a screenshot of your TUI with the theme and checking if your brand colors still pop.

**9. License your assets separately.** MIT your code. Protect your brand. State both clearly.

The entire brand system for shelfctl - spec, poses, wordmark, screencasts, themed screenshots - was built in less time than writing the architecture documentation. The tooling makes it fast. The spec makes it consistent. The result makes people stop scrolling.

---

**Project:** [github.com/blackwell-systems/shelfctl](https://github.com/blackwell-systems/shelfctl)

**Character spec:** [assets/shelby-spec.md](https://github.com/blackwell-systems/shelfctl/blob/main/assets/shelby-spec.md)

**VHS tape file:** [assets/tui_demo.tape](https://github.com/blackwell-systems/shelfctl/blob/main/assets/tui_demo.tape)

---

![Shelby faces](https://github.com/blackwell-systems/shelfctl/raw/main/assets/shelf_faces.png)
