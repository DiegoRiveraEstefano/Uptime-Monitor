# Design System & Visual Guidelines

This document defines the user interface (UI) and user experience (UX) guidelines for `UptimeMonitor`. It outlines the color palette, typography, visual hierarchy, status colors, and interactive state styles.

---

## 1. Design Philosophy
The design of `UptimeMonitor` focuses on **clarity, simplicity, and premium aesthetics**. 
*   **Minimalist & Clean**: Pure white backgrounds and light gray borders are used to emphasize content, graphs, and system states.
*   **Intentional Accents**: Pastel purple is used for interactive focal points (buttons, primary badges, navigation indicators, active states).
*   **Informative Statuses**: Status indicators (Healthy, Warning, Outage) are clearly readable but soft, preventing visual clutter.

---

## 2. Color System (Tailwind CSS v4 Configuration)

### Core Palette

| Name | Color Token | HSL / Hex Code | Usage |
| :--- | :--- | :--- | :--- |
| **Pure White** | `bg-white` | `#FFFFFF` | Main dashboard background, table rows, cards. |
| **Canvas** | `bg-slate-50` | `hsl(240, 20%, 98%)` | Sidebar background, dashboard wrapper backdrops. |
| **Border** | `border-slate-100` | `hsl(240, 10%, 94%)` | Dividers, card borders, table lines. |
| **Text Primary** | `text-slate-900` | `hsl(240, 10%, 12%)` | Headings, bold text, body reading. |
| **Text Secondary** | `text-slate-500` | `hsl(240, 8%, 45%)` | Subheadings, descriptions, metadata text. |

### Accent Colors (Pastel Purple)

| Token Name | HSL / Hex Code | Usage Example |
| :--- | :--- | :--- |
| **Purple Pastel Light** | `hsl(268, 100%, 97%)` | Badge backdrops, active sidebar background. |
| **Purple Accent** | `hsl(268, 80%, 75%)` | Primary button backgrounds, active switches. |
| **Purple Hover** | `hsl(268, 65%, 68%)` | Button hover state background. |
| **Purple Deep Text** | `hsl(268, 50%, 30%)` | Text color on top of pastel purple backgrounds (buttons/badges). |

### System Status Colors

| State | Token Name | HSL / Hex Code | Description |
| :--- | :--- | :--- | :--- |
| **Healthy (UP)** | `emerald-500` | `hsl(142, 60%, 45%)` | Soft emerald green. |
| **Degraded (Warning)**| `amber-500` | `hsl(38, 90%, 55%)` | Warm amber orange. |
| **Outage (DOWN)** | `rose-500` | `hsl(350, 80%, 55%)` | Crimson rose red. |

---

## 3. Typography & Hierarchy

We import Google Fonts for a modern geometric look:
*   **Primary Headings Font**: `"Outfit"`, sans-serif (clean, rounded, premium appearance).
*   **Body & UI Font**: `"Inter"`, sans-serif (high legibility, neutral).

### Font Scale Rules
*   **Page Titles (h1)**: `text-3xl` (30px), font weight `font-bold` (700), tracking `tracking-tight`. Font family `Outfit`.
*   **Section Headers (h2)**: `text-xl` (20px), font weight `font-semibold` (600). Font family `Outfit`.
*   **Table / Card Labels (h3)**: `text-sm` (14px), font weight `font-medium` (500), uppercase `uppercase`, tracking `tracking-wider` with text-slate-500.
*   **Body Reading**: `text-base` (16px) or `text-sm` (14px) for dashboard listings, font weight `font-normal` (400). Font family `Inter`.

---

## 4. Component Design Patterns

### Primary Buttons (Pastel Purple)
*   **Background**: `hsl(268, 80%, 75%)`
*   **Text**: `hsl(268, 50%, 30%)`, font weight `font-semibold` (600).
*   **Borders**: None or soft matching boundary.
*   **Shadow**: `shadow-sm` transitioning to `shadow-md` on hover.
*   **Transition Classes**: `transition-all duration-200 ease-in-out hover:bg-[hsl(268,65%,68%)] active:scale-98`

### Secondary / Ghost Buttons
*   **Background**: Transparent or `bg-slate-50` on hover.
*   **Border**: `border border-slate-100`.
*   **Text**: `text-slate-600`.

### Cards & Grid Layouts
*   **Background**: `bg-white`.
*   **Border**: `border border-slate-100` (no heavy shadows, flat minimalist cards).
*   **Corners**: `rounded-2xl` (16px) or `rounded-xl` (12px).
*   **Padding**: `p-6` (24px) for cards; `p-8` (32px) for main layouts.

---

## 5. Micro-Animations & Transitions

We use CSS transitions instead of JS-heavy animations to keep the interface responsive and fast:
1.  **Button Scale Press Effect**: On clicking buttons, scale them down slightly (`active:scale-98`).
2.  **Hover Fades**: All link highlights, sidebar links, and buttons must utilize `duration-150 ease-in-out` for opacity or background transitions.
3.  **Status Pulse**: Monitors that are currently offline or warning display a subtle breathing pulse on their status indicator badge (`animate-pulse`).
