# Parish Profile Data Structure

This document describes the structure of the `parish_profile` collection in Firebase Firestore.

## Collection: parish_profile

Document ID: `main`

### Fields

```json
{
  "parishName": "Sto. Rosario Parish Church",
  "parishNameTagalog": "Parokya ng Sto. Rosario",
  "history": {
    "introductionTagalog": "Nakaukit na sa kasaysayan ang pagiging relihiyoso ng mga mamamayan ng Malipampang...",
    "introductionEnglish": "The religiosity of the people of Malipampang is engraved in history...",
    "timelineEvents": [
      {
        "year": "1919",
        "titleTagalog": "Ang Simula ng Pananampalataya - Pagtatayo ng Unang Bisita",
        "titleEnglish": "The Beginning of Faith - Building the First Chapel",
        "descriptionsTagalog": [
          "Sa pamumuno ni Ingkong Dano Villaceran at ng mga matatanda ng nayon...",
          "Subalit pagkalipas ng isang taon, ito ay nabuwal ng bagyo..."
        ],
        "descriptionsEnglish": [
          "Led by Ingkong Dano Villaceran and the elders of the town...",
          "However, after one year, it was destroyed by a storm..."
        ]
      }
    ],
    "heritageTagalog": "Mula sa mga simpleng simula sa 1919...",
    "heritageEnglish": "From humble beginnings in 1919..."
  },
  "massSchedule": [
    {
      "tagalogDay": "ARAW-ARAW",
      "englishDay": "DAILY",
      "time": "6:30 AM",
      "iconName": "wb_sunny",
      "colorValue": -6543440,
      "category": 0
    },
    {
      "tagalogDay": "UNANG MISA",
      "englishDay": "FIRST MASS",
      "time": "6:30 AM",
      "iconName": "schedule",
      "colorValue": -15066598,
      "category": 1
    }
  ],
  "lastUpdated": {
    "_seconds": 1640995200,
    "_nanoseconds": 0
  }
}
```

### Field Descriptions

- `parishName`: The name of the parish in English
- `parishNameTagalog`: The name of the parish in Tagalog
- `history`: Object containing parish history information
  - `introductionTagalog/English`: Introduction text in both languages
  - `timelineEvents`: Array of historical events
    - `year`: Year of the event
    - `titleTagalog/English`: Event title in both languages
    - `descriptionsTagalog/English`: Array of description paragraphs
  - `heritageTagalog/English`: Heritage/mission statement
- `massSchedule`: Array of mass schedule items
  - `tagalogDay/englishDay`: Day label in both languages
  - `time`: Time of the mass
  - `iconName`: Icon identifier (wb_sunny, schedule, etc.)
  - `colorValue`: Color as integer value
  - `category`: 0 for daily, 1 for sunday
- `lastUpdated`: Timestamp of last update

### Mass Schedule Categories

- `0`: Daily masses
- `1`: Sunday masses

### Icon Names

- `wb_sunny`: For morning/daily masses
- `schedule`: For regular scheduled masses

### Color Values

Common color values:
- Orange: -6543440
- Primary Blue: -15066598
- Primary Gold: -1092784