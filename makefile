# Define flutter command
FLUTTER := flutter

# Main sequence: clean, get, build web, build android, run
.PHONY: all
all:
	flutter clean
	flutter pub get
	flutter run -d chrome --debug
dev:
	flutter clean
	flutter pub get
	flutter build web --release --tree-shake-icons
