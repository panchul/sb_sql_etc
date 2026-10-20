#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VENV_DIR="${VENV_DIR:-$SCRIPT_DIR/.venv}"
SPARK_HOME="${SPARK_HOME:-$HOME/spark}"
REQUIRED_JAVA_MAJOR=17

java_major_version() {
  local version_raw major remainder
  version_raw="$("$1" -version 2>&1 | awk -F '"' '/version/ {print $2; exit}')"
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

detect_java_home_17() {
  local candidate=""
  local major=""

  if [ -n "${JAVA_HOME:-}" ] && [ -x "${JAVA_HOME}/bin/java" ]; then
    major="$(java_major_version "${JAVA_HOME}/bin/java")"
    if [ -n "$major" ] && [ "$major" -ge "$REQUIRED_JAVA_MAJOR" ]; then
      echo "$JAVA_HOME"
      return 0
    fi
  fi

  if [ -x "/usr/libexec/java_home" ]; then
    candidate="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"
    if [ -n "$candidate" ] && [ -x "$candidate/bin/java" ]; then
      major="$(java_major_version "$candidate/bin/java")"
      if [ -n "$major" ] && [ "$major" -ge "$REQUIRED_JAVA_MAJOR" ]; then
        echo "$candidate"
        return 0
      fi
    fi
  fi

  if [ -x "/opt/homebrew/opt/openjdk@17/bin/java" ]; then
    candidate="/opt/homebrew/opt/openjdk@17"
    major="$(java_major_version "$candidate/bin/java")"
    if [ -n "$major" ] && [ "$major" -ge "$REQUIRED_JAVA_MAJOR" ]; then
      echo "$candidate"
      return 0
    fi
  fi

  if [ -x "/usr/local/opt/openjdk@17/bin/java" ]; then
    candidate="/usr/local/opt/openjdk@17"
    major="$(java_major_version "$candidate/bin/java")"
    if [ -n "$major" ] && [ "$major" -ge "$REQUIRED_JAVA_MAJOR" ]; then
      echo "$candidate"
      return 0
    fi
  fi

  if [ -x "/usr/lib/jvm/java-17-openjdk/bin/java" ]; then
    candidate="/usr/lib/jvm/java-17-openjdk"
    major="$(java_major_version "$candidate/bin/java")"
    if [ -n "$major" ] && [ "$major" -ge "$REQUIRED_JAVA_MAJOR" ]; then
      echo "$candidate"
      return 0
    fi
  fi

  if [ -x "/usr/lib/jvm/java-17-openjdk-amd64/bin/java" ]; then
    candidate="/usr/lib/jvm/java-17-openjdk-amd64"
    major="$(java_major_version "$candidate/bin/java")"
    if [ -n "$major" ] && [ "$major" -ge "$REQUIRED_JAVA_MAJOR" ]; then
      echo "$candidate"
      return 0
    fi
  fi

  return 1
}

print_java_actions_and_exit() {
  echo "Java diagnostics:" >&2
  if command -v java >/dev/null 2>&1; then
    echo "  java binary: $(command -v java)" >&2
    java -version 2>&1 | sed 's/^/  /' >&2
  else
    echo "  java binary: not found" >&2
  fi
  echo "  JAVA_HOME: ${JAVA_HOME:-<unset>}" >&2
  echo >&2
  echo "Spark requires Java ${REQUIRED_JAVA_MAJOR}+ for this sandbox." >&2
  echo "Suggested actions:" >&2
  echo "  - Run ./setup_local_spark.sh to install/check Java 17 and Spark." >&2
  echo "  - Or manually configure Java 17:" >&2
  echo "      macOS: brew install openjdk@17 && export JAVA_HOME=\$(/usr/libexec/java_home -v 17)" >&2
  echo "      Linux: sudo apt-get install -y openjdk-17-jdk && export JAVA_HOME=/usr/lib/jvm/java-17-openjdk" >&2
  echo "      export PATH=\"\$JAVA_HOME/bin:\$PATH\"" >&2
  exit 1
}

if [ ! -d "$VENV_DIR" ]; then
  echo "Python virtual environment not found. Run ./setup_local_spark.sh first." >&2
  exit 1
fi

JAVA_HOME_FOR_SPARK="$(detect_java_home_17 || true)"
if [ -n "$JAVA_HOME_FOR_SPARK" ]; then
  export JAVA_HOME="$JAVA_HOME_FOR_SPARK"
  export PATH="$JAVA_HOME/bin:$PATH"
  echo "Using Java 17 for this script run only: $JAVA_HOME"
fi

if ! command -v java >/dev/null 2>&1; then
  print_java_actions_and_exit
fi

JAVA_MAJOR="$(java_major_version java)"
if [ -z "$JAVA_MAJOR" ] || [ "$JAVA_MAJOR" -lt "$REQUIRED_JAVA_MAJOR" ]; then
  print_java_actions_and_exit
fi

echo "Java check passed (detected major version: $JAVA_MAJOR)."

# shellcheck disable=SC1090
source "$VENV_DIR/bin/activate"
export SPARK_HOME
export PATH="$SPARK_HOME/bin:$SPARK_HOME/sbin:$PATH"
export PYSPARK_PYTHON="$VENV_DIR/bin/python"

echo "Running Python Spark demo..."
python spark_sql_demo.py
