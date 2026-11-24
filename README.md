# 📱 Smart AI Expense Scanner & Receipt Tracker

A modern Flutter mobile application that uses **Multimodal AI (Google Gemini & Groq)** to scan physical paper receipts and bills, automatically extract merchant names, line-item breakdowns, and total amounts, and syncs everything with **Supabase Cloud Database & Auth**.

---

## ✨ Features

- **🧾 Instant AI Receipt Scanner:**
  - Multi-tiered AI OCR engine using **Google Gemini 3.5 Flash-lite** and **Groq Cloud AI**.
  - Automatically detects merchant/store name, bill date, total amount, category, and line-item breakdowns in ~2 seconds.
  - Interactive verification screen to edit or confirm detected details before saving.
  - Quick **"Today"** shortcut to update older dates on the fly.
  
- **✍️ Manual Expense Entry:**
  - Quick bottom sheet to record cash and untracked expenses in seconds.
  - Pre-filled quick merchant chips (e.g., *Three-Wheel, Keells, Pharmacy, Fuel, Tea & Snacks*).

- **📊 Monthly Budget Tracker:**
  - Dynamic spending progress bar with color-coded alerts (Green < 70%, Orange 70-90%, Red > 90%).
  - Configurable monthly budget limits stored locally and synced in real-time.

- **📈 Visual Analytics & Category Breakdown:**
  - Interactive **fl_chart** pie charts showing expense distribution across categories.
  - Filter by category (*Food & Dining, Groceries, Transportation, Utilities, Shopping, Entertainment, etc.*).
  - Real-time search by merchant name, item, or category.
  - **All-Time & Monthly views:** Easily toggle between current month expenses and complete lifetime transaction history.

- **📄 Export to PDF & Excel (.xlsx):**
  - Download or share professional PDF expense summaries directly via WhatsApp, Email, or Google Drive.
  - Export full spreadsheet-compatible `.xlsx` files with date, category, merchant, line-items, and amounts.

- **☁️ Supabase Cloud Backend:**
  - Secure Email/Password & Google Sign-In authentication.
  - Real-time PostgreSQL database with Row-Level Security (RLS) keeping your financial data private.

---

## 🛠️ Tech Stack

- **Frontend:** [Flutter](https://flutter.dev) (Dart 3.5+)
- **AI & Vision:** [Google Generative AI](https://pub.dev/packages/google_generative_ai) (Gemini 3.5 Flash-lite) & [Groq Cloud](https://groq.com)
- **Database & Auth:** [Supabase Flutter](https://pub.dev/packages/supabase_flutter)
- **Charts & UI:** [fl_chart](https://pub.dev/packages/fl_chart), Material 3
- **Exporting:** [pdf](https://pub.dev/packages/pdf), [excel](https://pub.dev/packages/excel), [share_plus](https://pub.dev/packages/share_plus)
- **Config:** [flutter_dotenv](https://pub.dev/packages/flutter_dotenv)

---

## 🚀 Getting Started

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.24+ recommended)
- Android Studio / VS Code with Flutter extension
- A [Supabase](https://supabase.com) account (Free tier)
- A [Google AI Studio](https://aistudio.google.com) API key (Free)
- (Optional) A [Groq](https://console.groq.com) API key (Free)

### 2. Clone the Repository
```bash
git clone https://github.com/YOUR_USERNAME/smart_expense_scanner.git
cd smart_expense_scanner
```

### 3. Install Dependencies
```bash
flutter pub get
```

### 4. Configure Environment Variables
Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```
Open `.env` and fill in your credentials:
```env
GEMINI_API_KEY=your_gemini_api_key_here
GROQ_API_KEY=your_groq_api_key_here
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key_here
```

### 5. Supabase Database Setup
Execute the following SQL in your Supabase SQL Editor:
```sql
CREATE TABLE public.expenses (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id text NOT NULL,
  merchant text NOT NULL,
  category text NOT NULL,
  total_amount numeric NOT NULL,
  currency text DEFAULT 'LKR',
  date timestamptz DEFAULT now(),
  image_url text,
  items jsonb DEFAULT '[]'::jsonb,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated full access"
ON public.expenses FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);
```

### 6. Run the App
```bash
flutter run
```

---

## 🔒 Security Note
Never commit your `.env` file to version control. The `.gitignore` is pre-configured to exclude sensitive keys.

---

## 📄 License
This project is open-source and available under the [MIT License](LICENSE).
