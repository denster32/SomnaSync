# SomnaSync

SomnaSync is an iOS sleep optimization app that leverages advanced AI/ML analysis and Apple Watch integration.

This repository contains the Swift sources as well as a zipped Xcode project in `Resources/`.

## Quick Start (Xcode)

1. **Clone the repository**
   ```bash
   git clone https://github.com/<your-github-username>/SomnaSync.git
   cd SomnaSync
   ```
2. **Unzip the project files**
   ```bash
   unzip Resources/SomnaSync-Pro-Xcode-Complete.zip
   cd SomnaSync-Pro-Xcode-Complete
   ```
3. **Open in Xcode**
   ```bash
   open SomnaSync.xcodeproj
   ```

See [Documentation/README.md](Documentation/README.md) for more details.

## Docker Quickstart

Docker provides an easy way to run Swift tools and tests in a clean environment.

1. **Install Docker** if it's not already available on your system.
2. **Clone this repository** (as shown above).
3. **Launch a Swift container** mounting the project directory:
   ```bash
   docker run --rm -it -v "$PWD":/workspace -w /workspace swift:6.1 bash
   ```
4. **Run the test scripts inside the container** to verify everything works:
   ```bash
   swift tests/test_background_health_analyzer.swift
   swift tests/test_volume_auto_change.swift
   swift tests/test_models.swift
   ```
5. You can now build or run other Swift commands from the same shell.

This approach allows you to experiment without installing Swift locally.
