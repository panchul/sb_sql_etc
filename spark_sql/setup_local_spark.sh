#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV_DIR="${VENV_DIR:-$SCRIPT_DIR/.venv}"
SPARK_HOME="${SPARK_HOME:-$HOME/spark}"
SPARK_VERSION="${SPARK_VERSION:-4.2.0}"
SPARK_PACKAGE="spark-${SPARK_VERSION}-bin-hadoop3"
SPARK_URL_DEFAULT="https://downloads.apache.org/spark/spark-${SPARK_VERSION}/${SPARK_PACKAGE}.tgz"
REQUIRED_JAVA_MAJOR=17

configure_java_17_if_available() {
  local candidate=""
  local major=""

  if [ -x "/usr/libexec/java_home" ]; then
    candidate="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"
    if [ -n "$candidate" ] && [ -x "$candidate/bin/java" ]; then
      major="$(java_major_version "$candidate/bin/java")"
      if [ -n "$major" ] && [ "$major" -ge "$REQUIRED_JAVA_MAJOR" ]; then
        export JAVA_HOME="$candidate"
        export PATH="$JAVA_HOME/bin:$PATH"
        return
      fi
    fi
  fi

  if [ -x "/opt/homebrew/opt/openjdk@17/bin/java" ]; then
    candidate="/opt/homebrew/opt/openjdk@17"
    major="$(java_major_version "$candidate/bin/java")"
    if [ -n "$major" ] && [ "$major" -ge "$REQUIRED_JAVA_MAJOR" ]; then
      export JAVA_HOME="$candidate"
      export PATH="$JAVA_HOME/bin:$PATH"
      return
    fi
  fi

  if [ -x "/usr/local/opt/openjdk@17/bin/java" ]; then
    candidate="/usr/local/opt/openjdk@17"
    major="$(java_major_version "$candidate/bin/java")"
    if [ -n "$major" ] && [ "$major" -ge "$REQUIRED_JAVA_MAJOR" ]; then
      export JAVA_HOME="$candidate"
      export PATH="$JAVA_HOME/bin:$PATH"
      return
    fi
  fi

  if [ -x "/usr/lib/jvm/java-17-openjdk/bin/java" ]; then
    candidate="/usr/lib/jvm/java-17-openjdk"
    major="$(java_major_version "$candidate/bin/java")"
    if [ -n "$major" ] && [ "$major" -ge "$REQUIRED_JAVA_MAJOR" ]; then
      export JAVA_HOME="$candidate"
      export PATH="$JAVA_HOME/bin:$PATH"
      return
    fi
  fi

  if [ -x "/usr/lib/jvm/java-17-openjdk-amd64/bin/java" ]; then
    candidate="/usr/lib/jvm/java-17-openjdk-amd64"
    major="$(java_major_version "$candidate/bin/java")"
    if [ -n "$major" ] && [ "$major" -ge "$REQUIRED_JAVA_MAJOR" ]; then
      export JAVA_HOME="$candidate"
      export PATH="$JAVA_HOME/bin:$PATH"
      return
    fi
  fi
}

java_major_version() {
  local java_cmd
  local version_raw major remainder
  java_cmd="${1:-java}"
  version_raw="$("$java_cmd" -version 2>&1 | awk -F '"' '/version/ {print $2; exit}')"
  if [ -z "$version_raw" ]; then
    echo ""
    return
  fi

  major="${version_raw%%.*}"
  if [ "$major" = "1" ]; then
    remainder="${version_raw#1.}"
    major="${remainder%%.*}"
  fi
  echo "$major"
}

print_java_diagnostics() {
  echo "Java diagnostics:"
  if command -v java >/dev/null 2>&1; then
    echo "  java binary: $(command -v java)"
    java -version 2>&1 | sed 's/^/  /'
  else
    echo "  java binary: not found"
  fi
  echo "  JAVA_HOME: ${JAVA_HOME:-<unset>}"
}

exit_with_java_actions() {
  print_java_diagnostics
  echo >&2
  echo "Spark ${SPARK_VERSION} requires Java ${REQUIRED_JAVA_MAJOR}+." >&2
  echo "Suggested actions:" >&2
  echo "  1) Install Java 17 (or newer)." >&2
  echo "     - macOS (Homebrew): brew install openjdk@17" >&2
  echo "     - Ubuntu/Debian: sudo apt-get update && sudo apt-get install -y openjdk-17-jdk" >&2
  echo "  2) Point JAVA_HOME to that installation and update PATH." >&2
  echo "     - macOS: export JAVA_HOME=\$(/usr/libexec/java_home -v 17)" >&2
  echo "     - Linux: export JAVA_HOME=/usr/lib/jvm/java-17-openjdk" >&2
  echo "     - export PATH=\"\$JAVA_HOME/bin:\$PATH\"" >&2
  echo "  3) Re-run: ./setup_local_spark.sh" >&2
  exit 1
}

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "Python 3 is required but was not found in PATH." >&2
  exit 1
fi

if ! command -v java >/dev/null 2>&1; then
  echo "Java 17 is not installed. Installing it automatically if supported..."
  if command -v brew >/dev/null 2>&1; then
    brew install openjdk@17
    export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y openjdk-17-jdk
    export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
  else
    echo "Could not detect a supported package manager for Java installation." >&2
    echo "Please install Java 17 manually, then re-run this script." >&2
    exit 1
  fi
fi

configure_java_17_if_available

JAVA_MAJOR="$(java_major_version)"
if [ -z "$JAVA_MAJOR" ] || [ "$JAVA_MAJOR" -lt "$REQUIRED_JAVA_MAJOR" ]; then
  echo "Detected Java version is too old for Spark ${SPARK_VERSION}."
  if command -v brew >/dev/null 2>&1; then
    echo "Attempting to install/refresh Java 17 via Homebrew..."
    brew install openjdk@17
    export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
  elif command -v apt-get >/dev/null 2>&1; then
    echo "Attempting to install/refresh Java 17 via apt-get..."
    sudo apt-get update
    sudo apt-get install -y openjdk-17-jdk
    export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
  fi

  JAVA_MAJOR="$(java_major_version)"
  if [ -z "$JAVA_MAJOR" ] || [ "$JAVA_MAJOR" -lt "$REQUIRED_JAVA_MAJOR" ]; then
    exit_with_java_actions
  fi
fi

if [ ! -d "$VENV_DIR" ]; then
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1090
source "$VENV_DIR/bin/activate"
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

if [ ! -d "$SPARK_HOME" ]; then
  echo "Spark distribution not found at $SPARK_HOME. Downloading it now..."
  SPARK_ARCHIVE="$(mktemp "${TMPDIR:-/tmp}/spark-${SPARK_VERSION}-XXXXXX.tgz")"
  trap 'rm -f "$SPARK_ARCHIVE"' EXIT

  SPARK_URL_IN_USE="${SPARK_URL:-$SPARK_URL_DEFAULT}"
  echo "Trying Spark download URL: $SPARK_URL_IN_USE"
  if ! curl --fail --location --show-error --silent \
    --retry 3 --retry-delay 2 \
    -o "$SPARK_ARCHIVE" \
    "$SPARK_URL_IN_USE"; then
    echo "Failed to download Spark ${SPARK_VERSION}." >&2
    echo "URL used: $SPARK_URL_IN_USE" >&2
    echo "Set SPARK_URL to a working .tgz URL and re-run the script if needed." >&2
    exit 1
  fi

  if ! tar -tzf "$SPARK_ARCHIVE" >/dev/null 2>&1; then
    echo "Downloaded file is not a valid gzip tar archive: $SPARK_ARCHIVE" >&2
    echo "URL used: $SPARK_URL_IN_USE" >&2
    exit 1
  fi

  tar -xzf "$SPARK_ARCHIVE" -C "$HOME"

  if [ ! -d "$HOME/$SPARK_PACKAGE" ]; then
    echo "Expected extracted directory was not found: $HOME/$SPARK_PACKAGE" >&2
    exit 1
  fi

  mv "$HOME/$SPARK_PACKAGE" "$SPARK_HOME"
fi

export SPARK_HOME
export PATH="$SPARK_HOME/bin:$SPARK_HOME/sbin:$PATH"
export PYSPARK_PYTHON="$VENV_DIR/bin/python"

cat <<EOF
Setup complete.

Environment variables for your current shell:
  export SPARK_HOME="$SPARK_HOME"
  export PATH="$SPARK_HOME/bin:$SPARK_HOME/sbin:$PATH"
  export PYSPARK_PYTHON="$VENV_DIR/bin/python"
  export JAVA_HOME="${JAVA_HOME:-$(java -XshowSettings:properties -version 2>&1 | grep 'java.home' | cut -d= -f2 | tr -d ' ')}"
  export PATH="\$JAVA_HOME/bin:\$PATH"

Important notes for beginners:
  - This script runs in its own shell process.
  - The exported variables above do NOT automatically persist in your terminal after the script exits.
  - Add them to ~/.zshrc or ~/.bashrc (recommended), or export them again before running Spark commands.
  - The run scripts try to auto-detect Java 17, but setting JAVA_HOME explicitly is still the most reliable option.

You can now run:
  ./run_python_demo.sh
  ./run_scala_demo.sh
EOF
