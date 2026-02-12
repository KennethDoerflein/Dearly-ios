# Dearly File Format Specification v1.3

> A portable interchange format for greeting card data with bundled images, version history, and multi-card backup support.

---

## Overview

The `.dearly` file format is a ZIP-based container that bundles greeting card metadata with associated images into a single, shareable file. It supports two modes:

1. **Single Card** - For sharing individual cards between users
2. **Backup Bundle** - For backing up/restoring multiple cards at once

| Property        | Value                              |
| --------------- | ---------------------------------- |
| **Extension**   | `.dearly`                          |
| **MIME Type**   | `application/zip`                  |
| **Version**     | `1.3`                              |
| **Compression** | STORE or DEFLATE (see [Compression](#compression)) |

---

## File Structure

### Single Card Export

```
card_export.dearly (ZIP archive)
├── manifest.json       ← Required: Format metadata and card data
├── front.jpg           ← Required: Front image of the card
├── back.jpg            ← Required: Back image of the card
├── inside_left.jpg     ← Optional: Inside left image (folded cards only)
├── inside_right.jpg    ← Optional: Inside right image (folded cards only)
└── versions/           ← Optional: Historical images (if exporting with history)
    ├── v1/
    │   └── front.jpg
    └── v2/
        └── back.jpg
```

### Backup Bundle (Multi-Card)

```
dearly_backup.dearly (ZIP archive)
├── manifest.json       ← Required: Format metadata with cards array
└── cards/              ← Required: Folder containing all card images
    ├── {card-id-1}/
    │   ├── front.jpg
    │   ├── back.jpg
    │   ├── inside_left.jpg  (optional)
    │   └── inside_right.jpg (optional)
    └── {card-id-2}/
        ├── front.jpg
        └── back.jpg
```

### Image Files

| Filename            | Required | Description                           |
| ------------------- | -------- | ------------------------------------- |
| `front.<ext>`       | ✅ Yes   | Front of the card                     |
| `back.<ext>`        | ✅ Yes   | Back of the card                      |
| `inside_left.<ext>` | ❌ No    | Inside left panel (folded cards only) |
| `inside_right.<ext>`| ❌ No    | Inside right panel (folded cards only)|

**Supported extensions:** `.jpg`, `.jpeg`, `.png`, `.webp`, `.heic`

> [!NOTE]
> The actual filename (including extension) is stored in the manifest's `images` object. Implementations should read the manifest to determine exact filenames.

---

## Manifest Schema

The `manifest.json` file contains all metadata for the file format and the card(s).

### Top-Level Structure (Single Card)

```json
{
  "formatVersion": 2,
  "bundleType": "single",
  "exportedAt": "2026-01-14T07:30:00.000Z",
  "card": { ... },
  "images": { ... },
  "versionHistory": [ ... ]
}
```

### Top-Level Structure (Backup Bundle)

```json
{
  "formatVersion": 3,
  "bundleType": "backup",
  "exportedAt": "2026-01-14T07:30:00.000Z",
  "cards": [
    { "id": "...", "images": { "front": "cards/abc123/front.jpg", ... }, ... },
    { "id": "...", "images": { "front": "cards/def456/front.jpg", ... }, ... }
  ]
}
```

| Field           | Type     | Required | Description                                      |
| --------------- | -------- | -------- | ------------------------------------------------ |
| `formatVersion` | `number` | ✅       | Format version (`2` for single, `3` for bundle)  |
| `bundleType`    | `string` | ❌       | `"single"` or `"backup"` (default: single)       |
| `exportedAt`    | `string` | ✅       | ISO 8601 timestamp of when the file was created  |
| `card`          | `object` | ⚠️       | Card metadata (single card mode only)            |
| `images`        | `object` | ⚠️       | Image filename mapping (single card mode only)   |
| `cards`         | `array`  | ⚠️       | Array of cards with embedded images (bundle only)|
| `versionHistory`| `array`  | ❌       | Edit history (single card mode only)             |

> [!IMPORTANT]
> Single card mode uses `card` + `images` fields. Backup bundle mode uses `cards` array.

---

### Card Object

The `card` object contains all card metadata **except** image file data.

```json
{
  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "date": "2025-12-25",
  "isFavorite": true,
  "sender": "Grandma",
  "occasion": "Christmas",
  "notes": "Handmade card with photos",
  "type": "folded",
  "aspectRatio": 0.714,
  "aiExtractedData": { ... },
  "createdAt": "2025-12-26T10:00:00.000Z",
  "updatedAt": "2025-12-26T10:05:00.000Z"
}
```

| Field             | Type                    | Required | Description                                                                 |
| ----------------- | ----------------------- | -------- | --------------------------------------------------------------------------- |
| `id`              | `string`                | ✅       | UUID v4 identifier for the card                                             |
| `date`            | `string`                | ✅       | User-assigned date in ISO 8601 format (`YYYY-MM-DD`)                        |
| `isFavorite`      | `boolean`               | ✅       | Whether the card is marked as a favorite                                    |
| `sender`          | `string`                | ❌       | Name of the person who sent/gave the card                                   |
| `occasion`        | `string`                | ❌       | Event/occasion (e.g., "Birthday", "Christmas", "Wedding")                   |
| `notes`           | `string`                | ❌       | User notes about the card                                                   |
| `type`            | `"folded"` \| `"flat"`  | ❌       | Physical card type (default: `"flat"`)                                      |
| `aspectRatio`     | `number`                | ❌       | Width/height ratio for consistent rendering                                 |
| `aiExtractedData` | `object`                | ❌       | AI-extracted metadata (see [AI Extracted Data](#ai-extracted-data-object))  |
| `createdAt`       | `string`                | ❌       | ISO 8601 timestamp when originally created                                  |
| `updatedAt`       | `string`                | ❌       | ISO 8601 timestamp when last modified                                       |

#### Card Types

| Type       | Description                                                      | Images Required                   |
| ---------- | ---------------------------------------------------------------- | --------------------------------- |
| `"flat"`   | Simple 2-sided card (front & back only)                          | `front`, `back`                   |
| `"folded"` | Traditional 4-panel card that opens like a book                  | `front`, `back`, optionally `inside_left`, `inside_right` |

---

### Images Object

Maps image slots to their filenames within the ZIP archive.

```json
{
  "front": "front.jpg",
  "back": "back.jpg",
  "insideLeft": "inside_left.png",
  "insideRight": "inside_right.png"
}
```

| Field         | Type     | Required | Description                          |
| ------------- | -------- | -------- | ------------------------------------ |
| `front`       | `string` | ✅       | Filename of front image in archive   |
| `back`        | `string` | ✅       | Filename of back image in archive    |
| `insideLeft`  | `string` | ❌       | Filename of inside left image        |
| `insideRight` | `string` | ❌       | Filename of inside right image       |

---

### AI Extracted Data Object

Optional object containing AI-processed metadata from card images.

```json
{
  "extractedText": "Merry Christmas!\nWith love from the whole family...",
  "detectedSender": "The Smith Family",
  "detectedOccasion": "Christmas",
  "sentiment": "positive",
  "mentionedDates": ["2025-12-25"],
  "keywords": ["family", "love", "holidays"],
  "status": "complete",
  "lastExtractedAt": "2025-12-26T10:00:00.000Z"
}
```

| Field               | Type                                      | Required | Description                                        |
| ------------------- | ----------------------------------------- | -------- | -------------------------------------------------- |
| `extractedText`     | `string`                                  | ❌       | Full OCR text extracted from card images           |
| `detectedSender`    | `string`                                  | ❌       | AI-detected sender name                            |
| `detectedOccasion`  | `string`                                  | ❌       | AI-detected occasion/holiday                       |
| `sentiment`         | `"positive"` \| `"neutral"` \| `"negative"` | ❌       | Detected sentiment/tone of message                |
| `mentionedDates`    | `string[]`                                | ❌       | Dates found in card text (`YYYY-MM-DD` format)     |
| `keywords`          | `string[]`                                | ❌       | Detected keywords/themes                           |
| `status`            | `string`                                  | ✅*      | Extraction status (see below)                      |
| `lastExtractedAt`   | `string`                                  | ❌       | ISO 8601 timestamp of last extraction              |
| `processingStartedAt` | `string`                                | ❌       | ISO 8601 timestamp when processing began           |
| `error`             | `object`                                  | ❌       | Error details if extraction failed                 |

**Extraction Status Values:**

| Status        | Description                    |
| ------------- | ------------------------------ |
| `"pending"`   | Extraction not yet attempted   |
| `"processing"`| Extraction currently in progress |
| `"complete"`  | Extraction completed successfully |
| `"failed"`    | Extraction failed              |

**Error Object (if status is `"failed"`):**

```json
{
  "type": "NETWORK_ERROR",
  "message": "Failed to connect to AI service",
  "retryable": true
}
```

| Error Type         | Description                           |
| ------------------ | ------------------------------------- |
| `NETWORK_ERROR`    | Network connectivity issue            |
| `QUOTA_EXCEEDED`   | API quota/rate limit exceeded         |
| `INVALID_IMAGE`    | Image could not be processed          |
| `PARSING_ERROR`    | Failed to parse AI response           |
| `API_KEY_MISSING`  | API key not configured                |
| `UNKNOWN_ERROR`    | Unspecified error                     |

---

## Implementation Guide

### Reading a `.dearly` File

1. **Verify ZIP structure**: Attempt to parse as a standard ZIP archive
2. **Read manifest**: Extract and parse `manifest.json`
3. **Validate version**: Check `formatVersion` is supported (currently must be `≤ 3`)
4. **Validate required images**: Ensure `images.front` and `images.back` files exist in archive
5. **Extract images**: Save images to local storage
6. **Build card object**: Construct card data from manifest, linking to saved images

### Writing a `.dearly` File

1. **Collect images**: Read front and back images (and optional inside images)
2. **Build manifest**: Create manifest JSON with card metadata and image filenames
3. **Create ZIP**: Add `manifest.json` and all images to a new ZIP archive
4. **Apply compression**: Use STORE (recommended) or DEFLATE compression
5. **Save with extension**: Write to file with `.dearly` extension

### Compression

Exporters may use either compression method:

| Method   | Description                                      | Recommendation |
| -------- | ------------------------------------------------ | -------------- |
| `STORE`  | No compression (fastest)                         | ✅ Recommended |
| `DEFLATE`| Standard ZIP compression                         | ✅ Supported   |

> [!TIP]
> **STORE is recommended** because card images are typically JPEG/PNG (already compressed). DEFLATE provides minimal size reduction but significantly increases export time.

### Version Compatibility

| File Version | App Supports | Behavior                                       |
| ------------ | ------------ | ---------------------------------------------- |
| `1`          | `≥ 1`        | Single card (Legacy)                           |
| `2`          | `≥ 1.2`      | Single card with History                       |
| `3`          | `≥ 1.3`      | Backup Bundle                                  |
| `> 3`        | `≤ 1.3`      | Reject with "unsupported version" error        |

> [!IMPORTANT]
> When importing, implementations should **generate a new UUID** for the card to avoid ID conflicts with existing cards in the user's collection.

---

## Error Handling

Implementations should handle these error conditions:

| Error Code            | Condition                                      |
| --------------------- | ---------------------------------------------- |
| `INVALID_ZIP`         | File is not a valid ZIP archive                |
| `MISSING_MANIFEST`    | `manifest.json` not found in archive           |
| `INVALID_MANIFEST`    | `manifest.json` is malformed or invalid JSON   |
| `UNSUPPORTED_VERSION` | `formatVersion` is higher than supported       |
| `MISSING_IMAGE`       | Required image file referenced in manifest not found |
| `INVALID_CARD_DATA`   | Card metadata fails validation                 |
| `WRITE_ERROR`         | Failed to write extracted images to storage    |

---

## Complete Example

### manifest.json

```json
{
  "formatVersion": 1,
  "exportedAt": "2026-01-14T07:30:00.000Z",
  "card": {
    "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
    "date": "2025-12-25",
    "isFavorite": true,
    "sender": "Grandma Rose",
    "occasion": "Christmas",
    "notes": "Beautiful handmade card with family photos",
    "type": "folded",
    "aspectRatio": 0.714,
    "aiExtractedData": {
      "extractedText": "Merry Christmas!\n\nWishing you joy and happiness...",
      "detectedSender": "Grandma Rose",
      "detectedOccasion": "Christmas",
      "sentiment": "positive",
      "keywords": ["christmas", "family", "love", "joy"],
      "status": "complete",
      "lastExtractedAt": "2025-12-26T10:00:00.000Z"
    },
    "createdAt": "2025-12-26T09:00:00.000Z",
    "updatedAt": "2025-12-26T10:00:00.000Z"
  },
  "images": {
    "front": "front.jpg",
    "back": "back.jpg",
    "insideLeft": "inside_left.jpg",
    "insideRight": "inside_right.jpg"
  }
}
```

---

## Version History

Optional array of version snapshots capturing edit history. Only included when exporting with "Include Edit History" option.

### Version Snapshot Object

```json
{
  "versionNumber": 1,
  "editedAt": "2026-01-15T10:30:00.000Z",
  "metadataChanges": [
    { "field": "sender", "previousValue": "Mom", "newValue": "Mother" }
  ],
  "imageChanges": [
    { "slot": "front", "previousFilename": "versions/v1/front.jpg" }
  ]
}
```

| Field            | Type     | Required | Description                                      |
| ---------------- | -------- | -------- | ------------------------------------------------ |
| `versionNumber`  | `number` | ✅       | Sequential version number (1-based)              |
| `editedAt`       | `string` | ✅       | ISO 8601 timestamp of the edit                   |
| `metadataChanges`| `array`  | ✅       | List of metadata field changes                   |
| `imageChanges`   | `array`  | ✅       | List of image slot changes                       |

### Limits

| Limit            | Value | Description                                      |
| ---------------- | ----- | ------------------------------------------------ |
| Metadata versions| 10    | Maximum metadata change snapshots retained       |
| Image versions   | 5     | Maximum historical images per slot               |

---

## Changelog

### Version 1.3
- Added `bundleType` field: `"single"` or `"backup"`
- Added `cards` array for multi-card backup bundles
- Backup bundles use `cards/` folder structure with card IDs as subfolders
- Format version `3` indicates backup bundle mode
- Single card exports remain backward compatible with v1.2

### Version 1.2
- Added optional `versionHistory` array for edit history
- Added `versions/` folder for historical images
- Format version bumped to `2` when history is included

### Version 1.1
- Added STORE compression support (recommended for export)
- DEFLATE remains supported for backwards compatibility

### Version 1.0 (Initial Release)
- ZIP-based container format
- Support for flat and folded card types
- Required front/back images, optional inside images
- Card metadata including sender, occasion, notes, dates
- AI-extracted data preservation
- STORE or DEFLATE compression (STORE recommended)

---

## License

This specification is provided for interoperability purposes. Implementations are free to use this format for reading, writing, and exchanging greeting card data.