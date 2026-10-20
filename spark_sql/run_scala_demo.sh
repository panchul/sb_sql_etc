#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

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

print_scala_failure_actions() {
  echo >&2
  echo "Scala Spark demo failed." >&2
  echo "Suggested actions:" >&2
  echo "  1) Re-run setup to verify Spark + Java installation:" >&2
  echo "       ./setup_local_spark.sh" >&2
  echo "  2) Verify Spark directly:" >&2
  echo "       \"$SPARK_HOME/bin/spark-shell\" --version" >&2
  echo "  3) If you see hostname/loopback warnings, they are usually non-fatal." >&2
  echo "     To silence them, run this script with SPARK_LOCAL_IP set, for example:" >&2
  echo "       SPARK_LOCAL_IP=127.0.0.1 ./run_scala_demo.sh" >&2
  echo "  4) If startup hangs at the prompt in manual shell usage, run the object explicitly:" >&2
  echo "       SparkSqlDemo.main(Array.empty[String])" >&2
}

if [ ! -x "$SPARK_HOME/bin/spark-shell" ]; then
  echo "Spark was not found at $SPARK_HOME. Run ./setup_local_spark.sh first." >&2
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

export SPARK_HOME
export PATH="$SPARK_HOME/bin:$SPARK_HOME/sbin:$PATH"

if [ ! -f "$SCRIPT_DIR/spark_sql_demo.scala" ]; then
  echo "Scala demo file was not found: $SCRIPT_DIR/spark_sql_demo.scala" >&2
  exit 1
fi

echo "Running Scala Spark demo in non-interactive mode..."
echo "Note: WARN lines about loopback address or native-hadoop are common and usually not fatal."

if ! spark-shell -i spark_sql_demo.scala <<'EOF'
SparkSqlDemo.main(Array.empty[String])
:quit
EOF
then
  print_scala_failure_actions
  exit 1
fi

echo "Scala Spark demo completed."
