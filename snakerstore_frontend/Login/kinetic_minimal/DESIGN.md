---
name: Kinetic Minimal
colors:
  surface: '#f9f9fa'
  surface-dim: '#dadadb'
  surface-bright: '#f9f9fa'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f3f4'
  surface-container: '#eeeeef'
  surface-container-high: '#e8e8e9'
  surface-container-highest: '#e2e2e3'
  on-surface: '#1a1c1d'
  on-surface-variant: '#444748'
  inverse-surface: '#2f3132'
  inverse-on-surface: '#f0f1f2'
  outline: '#747878'
  outline-variant: '#c4c7c7'
  surface-tint: '#5f5e5e'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#1c1b1b'
  on-primary-container: '#858383'
  inverse-primary: '#c8c6c5'
  secondary: '#ab3500'
  on-secondary: '#ffffff'
  secondary-container: '#fe6a34'
  on-secondary-container: '#5d1900'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#151c27'
  on-tertiary-container: '#7d8492'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#e5e2e1'
  primary-fixed-dim: '#c8c6c5'
  on-primary-fixed: '#1c1b1b'
  on-primary-fixed-variant: '#474646'
  secondary-fixed: '#ffdbd0'
  secondary-fixed-dim: '#ffb59d'
  on-secondary-fixed: '#390c00'
  on-secondary-fixed-variant: '#832600'
  tertiary-fixed: '#dce2f3'
  tertiary-fixed-dim: '#c0c7d6'
  on-tertiary-fixed: '#151c27'
  on-tertiary-fixed-variant: '#404754'
  background: '#f9f9fa'
  on-background: '#1a1c1d'
  surface-variant: '#e2e2e3'
typography:
  display-hero:
    fontFamily: Inter
    fontSize: 56px
    fontWeight: '800'
    lineHeight: 60px
    letterSpacing: -0.03em
  display-hero-mobile:
    fontFamily: Inter
    fontSize: 36px
    fontWeight: '800'
    lineHeight: 40px
    letterSpacing: -0.025em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 38px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: '700'
    lineHeight: 28px
    letterSpacing: -0.015em
  headline-sm:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: -0.01em
  price-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '800'
    lineHeight: 28px
    letterSpacing: -0.02em
  price-md:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '700'
    lineHeight: 22px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0em
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0em
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.01em
  label-badge:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 12px
    letterSpacing: 0.05em
  label-size:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1.5rem
  gutter-mobile: 0.75rem
  margin: 2rem
  margin-mobile: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.5rem
---

## Brand & Style

The design system embodies a modern, minimalist, and premium urban athletic aesthetic. Tailored for discerning sneaker enthusiasts, streetwear tastemakers, and athletic consumers, the interface combines architectural restraint with dynamic street-culture energy.

The aesthetic blends **Minimalism** with an **Athletic High-Contrast** rhythm. The foundational visual language relies on expansive white and off-white negative space, deep asphalt black structural elements, and surgical bursts of vibrant athletic orange. Visual weight is concentrated on footwear imagery, oversized technical typography, and confident micro-interactions. The interface communicates immediacy, exclusivity, and athletic precision without unnecessary decorative clutter.

## Colors

The color system operates on high-contrast binary foundations accentuated by tactical athletic pigments.

- **Primary Canvas & Dominance**: `#111111` anchors typography, primary actions, heavy headers, and silhouette frames. Pure `#FFFFFF` serves as container and card fill, seated atop the `#F7F7F8` subtle canvas backdrop to establish seamless natural layers.
- **Brand Accent**: `#FF6B35` is reserved strictly for high-urgency callouts, limited drop releases, active selection states, and secondary dynamic actions. It should be applied deliberately to preserve its visual impact.
- **Tonal Neutrals**: `#6B7280` provides muted contrast for secondary specs, model SKUs, metadata, and inactive iconography. `#E5E7EB` sets precise, razor-sharp 1px structural dividing lines.
- **Functional Semantics**: `#16A34A` handles successful stock confirmation and checkout validation, while `#DC2626` governs stock depletion, validation errors, and high-priority sale warnings.

## Typography

The type system is powered entirely by `Inter`, leveraging its technical precision and optical balance.

- **Numerics & Currencies**: All monetary figures (`S/.`) and sizing tiers utilize tabular or tight tracking (`-0.02em`) with weight tiers between `700` and `800` to mirror technical sneaker box labeling and athletic timing displays.
- **Badging & Micro-Labels**: Uppercase transformations paired with tracking values of `+0.05em` are applied to release tags ("NUEVO", "STOCK LIMITADO", "DROP EXCLUSIVO") to anchor visual priority at small scales.
- **Scalability**: Desktop hero configurations scale cleanly into compressed mobile viewports through explicit mobile-first alternate tokens.

## Layout & Spacing

The layout model is governed by an 8pt architectural rhythm, structuring content across fluid, screen-responsive columns.

- **Desktop (1024px+)**: 12-column layout with `2rem` outer page margins and `1.5rem` internal gutters. Product card grids display in 3 or 4 columns.
- **Tablet (768px – 1023px)**: 8-column layout with `1.5rem` margins and `1rem` gutters. Product cards condense to 2 or 3 columns.
- **Mobile (< 768px)**: 4-column layout utilizing a compact `1rem` margin and `0.75rem` gutter to maximize image visibility. Product displays shift to high-density 2-column or full-width editorial single-column arrangements. Mobile screen bottom padding must always include clearance (minimum `5rem`) for the fixed mobile navigation bar.

## Elevation & Depth

Visual hierarchy uses a crisp, modern low-elevation philosophy that relies primarily on **tonal layers** and **subtle ambient shadows** rather than heavy blurred layering.

- **Base Layer (Level 0)**: Background canvas `#F7F7F8`. Completely flat.
- **Card & Surface Layer (Level 1)**: Pure `#FFFFFF` surfaces defined by a 1px border of `#E5E7EB`.
- **Card Hover State (Level 2)**: Sneaker cards elevate via a `-4px` vertical transform and an ambient diffused shadow: `0 12px 24px -6px rgba(17, 17, 17, 0.08)`. The internal neutral product backdrop shifts slightly lighter.
- **Floating Modals & Bottom Navigation (Level 3)**: Sticky bottom controls and mobile navigation draw from `0 -4px 16px -2px rgba(17, 17, 17, 0.06)` with a backdrop blur (`backdrop-blur-md bg-white/95`) to maintain legibility over underlying shoe catalogs.

## Shapes

The design system maintains a balanced, tactile geometry with a medium rounded baseline (`0.5rem` / `8px` corner radius) paired with specialized pill forms.

- **Standard Containers & Cards**: Defined at `rounded-xl` (`1rem` / `16px`) for shoe display frames, promotional banners, and modal dialogs.
- **Pill Selectors & Badges**: Fully rounded (`rounded-full` / `9999px`) for size chips, search filters, state tags, and floating action buttons.
- **Interactive Buttons**: Standard primary CTAs utilize `rounded-xl` (`16px`) or `rounded-full` according to screen density, mirroring sneaker silhouette geometry.

## Components

### Sneaker Product Cards
- **Backdrop & Container**: Housed in a `rounded-xl` frame with a `#FFFFFF` body and a `#F7F7F8` inner shoe cutout canvas. Features an intentional 1:1 or 4:5 aspect ratio.
- **Badges**: Pinned to the top corners. Top-left features dynamic stock pills (`#111111` background with `#FFFFFF` text for "NUEVO"; `#DC2626` background with `#FFFFFF` text for "STOCK LIMITADO"). Top-right houses a floating circular wishlist toggle (`#FFFFFF` with `#111111` icon).
- **Metadata**: Left-aligned brand name (`text-xs text-[#6B7280] uppercase tracking-wider`), sneaker title (`text-sm font-semibold text-[#111111] truncate`), and Peruvian Soles price tag (`text-base font-extrabold text-[#111111]`). Available sizes (`EU 40-44`) sit at the bottom in `text-xs text-[#6B7280]`.
- **Interactivity**: Hover lifts the card `-4px` with smooth transition (`duration-200 ease-out`).

### EU Shoe Size Selector Chips
- **Geometry**: Compact square-pill containers (`h-10 min-w-10 px-2 flex items-center justify-center rounded-lg border text-sm font-semibold transition-all`).
- **Default State**: Background `#FFFFFF`, border `#E5E7EB`, text `#111111`.
- **Selected State**: Background `#111111`, border `#111111`, text `#FFFFFF`.
- **Disabled / Out of Stock**: Background `#F7F7F8`, border-dashed `#E5E7EB`, text `#6B7280` with a clean diagonal strike-through rule.

### Action Buttons
- **Primary Athletic CTA**: `#111111` background, `#FFFFFF` text, `rounded-xl` or `rounded-full`, `h-12 px-6`, font weight `600`. Hover state triggers a shift to `#FF6B35` or an opacity layer (`opacity-90`).
- **Accent CTA ("Comprar Ahora")**: `#FF6B35` background, `#FFFFFF` text, `rounded-xl`, high contrast with an ambient `#FF6B35`/20 shadow on hover.
- **Secondary Ghost Button**: `#FFFFFF` background, 1px border `#E5E7EB`, `#111111` text. Hover transitions to `#F7F7F8`.

### Search Input & Quick Filter Pills
- **Search Bar**: `h-11`, background `#F7F7F8`, border 1px transparent, `rounded-full`, left-aligned Lucide `Search` icon in `#6B7280`, input placeholder in `#6B7280`. Focused state transitions border to `#111111` with a `#FFFFFF` fill.
- **Quick Filters**: Horizontal scroll list of `rounded-full` pills (`h-8 px-4 text-xs font-medium`). Unselected: `#FFFFFF` border `#E5E7EB` text `#111111`. Active: `#111111` background, `#FFFFFF` text.

### Mobile Bottom Navigation Bar
- **Structure**: Fixed bottom container `h-16 w-full bg-white/95 backdrop-blur-md border-t border-[#E5E7EB] px-4 flex items-center justify-around z-50`.
- **Items**: 5 key destinations: *Inicio* (Home), *Catálogo* (Grid), *Carrito* (Shopping Bag), *Pedidos* (Package), and *Perfil* (User).
- **Icons & Badges**: Lucide stroke icons (`20px`, stroke-width `1.75`). Inactive items in `#6B7280`; active item highlighted in `#111111` with a 4px dot below the icon. Cart item includes an absolute-positioned badge (`h-4 min-w-4 bg-[#FF6B35] text-white text-[10px] font-bold rounded-full flex items-center justify-center -top-1 -right-2`).