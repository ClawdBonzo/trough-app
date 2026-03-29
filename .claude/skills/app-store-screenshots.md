---
name: app-store-screenshots
description: Generate professional App Store screenshots using ScreenshotWhale API. Use when the user wants to create, update, or regenerate app store screenshots.
---

# Generate App Store Screenshots with ScreenshotWhale

## App Details (Trough-specific)
- **App name**: Trough - TRT Tracker
- **What it does**: TRT and hormone tracking app for men. Logs injections, tracks daily wellness, shows PK curves, provides personalized insights.
- **Colors**: Background #1A1A2E, Accent #E94560, Cards #16213E, Secondary #0F3460, Text white
- **Font**: SF Pro Rounded

## Features to highlight (in order):
1. Protocol Score — daily wellness score at a glance
2. Daily check-in — 30-second wellness logging
3. Injection tracking with site rotation
4. PK curve visualization
5. Trial/subscription value proposition
6. Compound tracking (GLP-1, peptides, AI)

## Process
1. Ask user for 6-10 screenshots placed in `screenshots/` directory
2. Read screenshots, resize to max 1290px width
3. Write compelling copy (emotional benefit, not feature names)
4. Build project JSON with all 18 device sizes (7 iOS phones + 7 iPads + 4 Android phones)
5. Send to ScreenshotWhale API
6. Return editor URL to user

## Copy Guidelines
- Headlines: 3-6 words, emotional benefit
- Subtitles: 6-12 words, adds context
- Examples: "Everything at a Glance" not "Dashboard View", "Track What Matters" not "Daily Check-in Screen"

## API Endpoint
POST https://storeshots-backend.onrender.com/api/projects/create-from-skill
No auth required. Returns editorUrl with claim token.

## Device Sizes (must generate ALL 18)
### iOS Phones
| Device | W | H | mockupType | headlineFontSize | subtitleFontSize |
|---|---|---|---|---|---|
| iPhone 6.9" (1320 x 2868) | 1320 | 2868 | iphone-17-pro-max | 21 | 15 |
| iPhone 6.9" (1290 x 2796) | 1290 | 2796 | iphone-17-pro-max | 21 | 15 |
| iPhone 6.9" (1260 x 2736) | 1260 | 2736 | iphone-17-pro-max | 20 | 14 |
| iPhone 6.5" (1284 x 2778) | 1284 | 2778 | iphone-16-pro | 21 | 15 |
| iPhone 6.5" (1242 x 2688) | 1242 | 2688 | iphone-16-pro | 21 | 15 |
| iPhone 6.3" (1206 x 2622) | 1206 | 2622 | iphone-17-pro | 20 | 14 |
| iPhone 6.3" (1179 x 2556) | 1179 | 2556 | iphone-17-pro | 21 | 15 |

### iPads
| Device | W | H | mockupType | headlineFontSize | subtitleFontSize |
|---|---|---|---|---|---|
| iPad 13" (2064 x 2752) | 2064 | 2752 | iphone-17-pro | 23 | 16 |
| iPad 13" (2048 x 2732) | 2048 | 2732 | iphone-17-pro | 23 | 16 |
| iPad 12.9" (2048 x 2732) | 2048 | 2732 | iphone-17-pro | 23 | 16 |
| iPad 11" (1668 x 2420) | 1668 | 2420 | iphone-17-pro | 21 | 15 |
| iPad 11" (1668 x 2388) | 1668 | 2388 | iphone-17-pro | 21 | 15 |
| iPad 11" (1640 x 2360) | 1640 | 2360 | iphone-17-pro | 21 | 15 |
| iPad 11" (1488 x 2266) | 1488 | 2266 | iphone-17-pro | 20 | 14 |

### Android Phones
| Device | W | H | mockupType | headlineFontSize | subtitleFontSize |
|---|---|---|---|---|---|
| Pixel 10 Pro XL | 1344 | 2992 | pixel-10-pro-xl | 20 | 14 |
| Pixel 10 Pro | 1280 | 2856 | pixel-10-pro | 21 | 15 |
| Pixel 10 | 1080 | 2424 | pixel-10 | 20 | 14 |
| Samsung Galaxy S25 | 1080 | 2340 | samsung-s25 | 21 | 14 |

## Layout Patterns (rotate, never repeat consecutively)
- **A**: Text top center, device bottom center (hero)
- **B**: Text top left, device below centered
- **C**: Device top, text bottom
- **D**: Text top, large device below

## Mockup Centering Formula
```
PHONE_ASPECT = 19.5 / 9
mockup_h = round(H * height_ratio)
mockup_w = round(mockup_h / PHONE_ASPECT)
mockup_x = round((W - mockup_w) / 2)
```

## JSON Schema Key Rules
- Device field: `deviceName` (not `name`)
- Text field: `content` (not `text`)
- Image ref: `"src": "img:<key>"` (not `imageKey`)
- fontWeight: string `"700"` (not number)
- Gradient stops: position 0 and 100 (not 0 and 1)
- fontSize: must come from table above, never above 23
