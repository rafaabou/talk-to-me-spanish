# User Guide — Talk To Me Spanish

**Version 1.6.0** | By Mohamed Rafaa Tounekti

Learn Spanish from zero to fluency. 100% offline, trilingual (Spanish + English + Arabic).

---

## Getting Started

### Installation

1. Download the APK from [GitHub Releases](https://github.com/rafaabou/talk-to-me-spanish/releases)
2. Open the APK on your Android device (Android 7.0+)
3. Allow installation from unknown sources if prompted
4. Open the app

### First Launch

The app starts with a 4-page welcome tour:
1. Welcome to Spanish
2. Structured Lessons (72 lessons from A1 to C2)
3. Smart Flashcards with spaced repetition
4. Keep your streak with daily study

Tap **Start** to begin.

### Web Version

You can also run the app in your browser:
1. Download `index.html` and `start-server.sh` from the repository root
2. Run `./start-server.sh`
3. Open `http://localhost:8002` in your browser

---

## Home Screen

The home screen is your dashboard with:

- **Continue card** — Resume your last lesson with one tap
- **Progress card** — See how many lessons you've completed and your current streak
- **Due card** — Words due for review from flashcards
- **Quick actions** — 6 buttons: Flashcards, Search, Grammar, Favorites, Verbs, Stats
- **Bottom Navigation** — 5 tabs: Inicio, Cartas, Verbos, Estadisticas, Cuenta
- **Quizzes** — One card per level (A1-C2), each with 10 questions
- **Lessons** — All levels listed with lesson counts and completion status

### App Bar Actions

- **Export** — Copy your progress to clipboard
- **Language** — Switch between English, Arabic, and Spanish UI
- **Theme** — Light, Dark, or System
- **Settings** — Audio speed, repeat count, zoom, export/import, reset

---

## Lessons

### Structure

Each level (A1-C2) contains 12 lessons. Each lesson includes:

| Section | Description |
|---------|-------------|
| **Objectives** | What you'll learn in this lesson |
| **Vocabulary** | Words with IPA pronunciation, English/Arabic translation, example sentences |
| **Grammar** | Grammar rules with explanations and examples |
| **Dialogue** | Conversations between speakers with audio |
| **Reading** | Reading passages in Spanish with translations |
| **Speaking** | Listen-and-repeat phrases with progress checkboxes |
| **Exercises** | Interactive practice (8 types) |
| **Cultural Tips** | Cultural context about Spain and Latin America |
| **Notes** | Your personal notes for this lesson |

### Exercise Types

| Type | How It Works |
|------|-------------|
| **Multiple Choice** | Tap the correct translation from 4 options |
| **Fill in the Blank** | Choose the word that completes the sentence |
| **Listening** | Play audio, then select what you heard |
| **Listening MCQ** | Play audio, then choose the correct translation |
| **Dictation** | Type what you hear in Spanish |
| **Writing** | Translate the given text |
| **Translation** | Translate between languages |
| **Sentence Reorder** | Drag words into the correct order |
| **Match Pairs** | Tap Spanish words, then tap their English matches |

### Audio

- Tap the **speaker icon** next to any word to hear pronunciation
- Audio uses Microsoft Edge TTS (es-UY-ValentinaNeural voice)
- Adjust speed in Settings (0.5x, 0.75x, 1.0x)
- Set repeat count (1x, 3x, 7x, 10x) to hear pronunciation multiple times

### Navigation

- Use **Previous** / **Next** arrows in the app bar to move between lessons
- Tap **Mark Complete** when you finish a lesson
- Use **Search** to find content within the current lesson

---

## Flashcards

### How It Works

Flashcards use **FSRS** (Free Spaced Repetition Scheduler), a scientifically proven algorithm that optimizes when you see each card.

1. Open Flashcards from the home screen
2. See a Spanish word with audio
3. Think about the translation
4. Tap the card to reveal the answer
5. Rate yourself:
   - **Again** (orange) — You didn't know it
   - **I know it** (primary) — You got it right
   - **Easy** (green) — Too easy

### What Happens Next

- Cards rated "Again" are re-added to your session
- "I know it" cards are scheduled for later review
- "Easy" cards are scheduled much further in the future
- The algorithm learns your pattern and optimizes review timing

### Repeat Count

Use the repeat selector (1x, 3x, 7x, 10x) to control how many times "Again" cards reappear in one session.

### Session Complete

When all cards are done, you see:
- Percentage of cards you knew
- Option to start a new session

---

## Verb Conjugation

### Browsing Verbs

1. Tap **Verbs** on the home screen
2. Browse 1,816 verbs grouped by type:
   - **-AR verbs** (e.g., hablar, cantar, trabajar)
   - **-ER verbs** (e.g., comer, beber, aprender)
   - **-IR verbs** (e.g., abrir, dormir, escribir)
   - **-OR verbs** (e.g., correr, vender)
   - **Irregular verbs** (e.g., ser, estar, tener, ir)
3. Use the **search bar** to find a specific verb
4. Toggle **Audio filter** to show only verbs with full audio
5. Use the **Comunes** filter to show only the 50 most frequently used verbs.

### Verb Detail

Tap any verb to see its full conjugation:

1. Select a tense from the chip bar:
   - Presente (Present)
   - Pretérito (Preterite)
   - Imperfecto (Imperfect)
   - Futuro (Future)
   - Condicional (Conditional)
   - Subjuntivo (Subjunctive)
   - Subjuntivo Pretérito (Subjunctive Past)
   - Imperativo (Imperative)
2. See conjugation for all persons (yo, tu, el/ella, nosotros, ustedes, ellos/ellas)
3. Tap the speaker icon to hear each form

### Verb Quiz

From any verb's detail screen, tap **Quiz** to test your knowledge of that verb's conjugations.

---

## Quizzes

### Level Quizzes

1. Tap any level card (A1-C2) on the home screen
2. Answer 10 random questions from all exercises in that level
3. See your score and best score
4. Review any mistakes you made

### Results

- **Trophy** — Score 8/10 or higher
- **Book** — Score below 8/10
- Your **best score** is saved per level
- Review your mistakes to learn from them

---

## Search

### Global Search

1. Tap **Search** on the home screen
2. Type in any language (Spanish, English, or Arabic)
3. Search across all 72 lessons
4. Results show the level, lesson, and content type
5. Tap a result to navigate directly to that lesson

### In-Lesson Search

1. While in a lesson, tap the **search icon** in the app bar
2. Search within the current lesson only
3. Results are organized by section (vocabulary, grammar, dialogue, etc.)
4. Tap a result to scroll to that section

---

## Grammar Reference

1. Tap **Grammar** on the home screen
2. Browse all grammar entries organized by CEFR level (A1-C2)
3. Expand any entry to see explanation and examples
4. Tap the speaker icon to hear example sentences

---

## Favorites

1. Tap the **star icon** next to any vocabulary word
2. View all favorites from the home screen
3. Listen to audio for any favorited word
4. Remove favorites by tapping the star again

---

## Statistics

Tap **Stats** on the home screen to see:

- **Lessons completed** — X out of 72
- **Exercises completed** — Total exercises done
- **Favorites** — Number of bookmarked words
- **Day streak** — Consecutive days studied
- **Activity calendar** — Monthly heatmap showing study days
- **14-day chart** — Bar chart of recent activity
- **Best quiz scores** — Your best score per level

---

## Achievements

Earn 17 achievement badges as you learn:

| Badge | Requirement |
|-------|------------|
| Primeros Pasos | Complete your first lesson |
| Estudiante | Complete 5 lessons |
| Estudioso | Complete 20 lessons |
| Maestro | Complete 50 lessons |
| Formado | Complete all 72 lessons |
| Empezando | Complete 10 exercises |
| Practica Hace al Maestro | Complete 100 exercises |
| Maestro de Ejercicios | Complete 500 exercises |
| Coleccionista | Add 5 words to favorites |
| En Llamas | Study 3 days in a row |
| Guerrero de la Semana | Study 7 days in a row |
| Campeon Mensual | Study 30 days in a row |
| Puntuacion Perfecta | Get 10/10 on any quiz |
| Entrenador Cerebral | Review 50 flashcards |
| Maestro de la Memoria | Review 200 flashcards |
| Explorador | Study on 10 different days |
| Estudiante Dedicado | Study on 30 different days |
| Maestro de la Voz | Complete 10 speaking exercises |
| Guardian de Datos | Export your progress for the first time |

View your achievements on the Estadisticas screen.

---

## Settings

Access from the app bar menu:

| Setting | Options | Description |
|---------|---------|-------------|
| **Audio Speed** | 0.5x, 0.75x, 1.0x | How fast audio plays |
| **Repeat Count** | 1, 3, 7, 10 | How many times audio repeats |
| **Text Zoom** | +/- 10% | Scale text size (0.8x to 2.0x) |
| **Theme** | Light, Dark, System | App appearance |
| **Language** | English, Arabic, Spanish | UI language |
| **Export Progress** | File or Clipboard | Save your progress |
| **Import Progress** | Select file | Restore progress from backup |
| **Reset Progress** | With confirmation | Delete all progress |

---

## Account & Backup

Access from the **Cuenta** tab in the bottom navigation bar:

- **Profile** — Your learner status (saved locally)
- **Respaldo** — Export/Import/Share your progress as JSON
- **Clear Data** — Reset all progress (with confirmation)
- **Acerca de** — App version and privacy info

Your data never leaves your device. Backup creates a local JSON file you can store anywhere.

---

## Data Management

### Export

Your progress is saved locally. You can export it as:
- **JSON file** — Full backup of all progress
- **Clipboard** — Quick text summary

### Import

Restore your progress from a previously exported JSON file. This is useful when:
- Switching phones
- Reinstalling the app
- Restoring from backup

### Web Export

On the web version, export downloads a JSON file. Import opens a file picker.

---

## Accessibility

- **Pinch-to-zoom** — Use two fingers to scale text anywhere in the app (0.8x to 2.0x)
- **Trilingual display** — Read in Spanish, English, or Arabic (with RTL support)
- **Audio pronunciation** — Every word has audio playback
- **High contrast** — Green theme with good contrast ratios

---

## Offline Usage

The app works 100% offline:
- All 72 lessons are bundled in the app
- All 5,932 audio files are included
- All 1,816 verb conjugations are available
- No internet connection required
- No data is sent anywhere

---

## Tips for Learning

1. **Study daily** — Even 5 minutes a day builds a strong streak
2. **Use flashcards** — The spaced repetition system optimizes your review
3. **Complete lessons in order** — A1 through C2 builds systematically
4. **Listen to audio** — Train your ear with native pronunciation
5. **Mark lessons complete** — Track your progress honestly
6. **Review mistakes** — Take quizzes again to improve weak areas
7. **Favorite difficult words** — Create a personal review list

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No audio | Check that volume is on; try adjusting audio speed in settings |
| App crashes | Clear app data and re-import your progress backup |
| Can't export | Check storage permissions; try clipboard export instead |
| Text too small | Use pinch-to-zoom or adjust zoom in settings |
| Progress lost | Import your last backup from Settings > Import Progress |

---

## Support

- **Issues**: https://github.com/rafaabou/talk-to-me-spanish/issues
- **Author**: Mohamed Rafaa Tounekti
- **License**: Apache-2.0

---

**Maintainer**: Mohamed Rafaa Tounekti
**Repository**: https://github.com/rafaabou/talk-to-me-spanish
