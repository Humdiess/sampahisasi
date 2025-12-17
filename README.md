# Sampahisasi

A Flutter application that uses AI (TensorFlow Lite) to classify waste as Organic or Non-Organic in real-time. Now features an AI Chatbot powered by Google Gemini to answer your waste management questions.

## Features

-   **Real-time Waste Classification**: Detects Organic/Anorganic waste using the camera.
-   **AI Chatbot**: Ask "Sampahisasi Helper" for recycling tips and waste info (powered by Gemini).
-   **Gallery Support**: Classify images directly from your photo gallery.
-   **Flash & Selfie Support**: Toggle flashlight and switch between front/back cameras.
-   **Clean UI**: Minimalist, distraction-free interface.

## Setup

1.  **Clone the repository**.
2.  **Environment Variables**:
    -   Create a file named `.env` in the root directory.
    -   Add your Google Gemini API key:
        ```env
        GEMINI_API_KEY=your_actual_api_key_here
        ```
3.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```
4.  **Run the App**:
    ```bash
    flutter run
    ```

## Building APK

To build a release APK:

```bash
flutter build apk --release
```

## Icons

To update the app icon, place your icon at `assets/icon/app_icon.png` and run:

```bash
flutter pub run flutter_launcher_icons
```
## License

This project is licensed under the  
**Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)**.

You may use, modify, and share this project **for non-commercial purposes only**.

