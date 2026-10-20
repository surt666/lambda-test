#!/usr/bin/env bash
# Scaffold a Clojure app with deps-new, clj-kondo, reitit + malli and optional AWS Lambda/SAM setup.
set -euo pipefail

DEPS_NEW='{:deps {io.github.seancorfield/deps-new {:git/tag "v0.16.0" :git/sha "bac3a23"}}}'

usage() {
  cat <<USAGE
Usage: $(basename "$0") <org/name> [options]

Options:
  --dir <path>   Target directory (default: ./<name>)
  --no-reitit    Don't add reitit
  --no-malli     Don't add malli
  --lambda       Add an AWS Lambda handler (needs reitit and malli)
  -h, --help     Show this help
USAGE
}

name=""
dir=""
reitit=true
malli=true
lambda=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) dir="$2"; shift 2 ;;
    --no-reitit) reitit=false; shift ;;
    --no-malli) malli=false; shift ;;
    --lambda) lambda=true; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    *) [[ -z "$name" ]] || { echo "Unexpected argument: $1" >&2; exit 1; }
       name="$1"; shift ;;
  esac
done

[[ "$name" == */* ]] || { echo "Project name must be <org>/<name>, e.g. surt666/my-app" >&2; usage >&2; exit 1; }

org="${name%%/*}"
project="${name#*/}"
dir="$(realpath -m "${dir:-$project}")"
if $lambda && ! { $reitit && $malli; }; then
  echo "--lambda can't be combined with --no-reitit or --no-malli" >&2; exit 1
fi
[[ ! -e "$dir" ]] || { echo "Target already exists: $dir" >&2; exit 1; }

command -v clj-kondo >/dev/null || { echo "clj-kondo not found on PATH" >&2; exit 1; }

echo "Creating $name in $dir..."
# Run outside any project so a local deps.edn can't interfere.
(cd "$(mktemp -d)" && clojure -Sdeps "$DEPS_NEW" -X org.corfield.new/app \
  :name "$name" :target-dir "\"$dir\"")

cd "$dir"

deps=()
if $reitit; then deps+=("metosin/reitit-ring 0.11.0"); fi
if $malli; then deps+=("metosin/malli 0.20.3"); fi
if $reitit && $malli; then deps+=("metosin/reitit-malli 0.11.0"); fi
if $lambda; then
  deps+=("metosin/reitit-middleware 0.11.0"
         "com.amazonaws/aws-lambda-java-core 1.4.0"
         "com.paulbutcher/ring-lambda-adapter 1.0.7")
fi

# Names deps-new derived from <org/name>, e.g. surt666.my-app and net.clojars.surt666/my-app.
ns="$(sed -n "s/^(def main '\(.*\))\$/\1/p" build.clj)"
lib="$(sed -n "s/^(def lib '\(.*\))\$/\1/p" build.clj)"
ns_path="$(tr '.-' '/_' <<<"$ns")"

add_deps() {
  [[ ${#deps[@]} -gt 0 ]] || return 0
  echo "Adding dependencies..."
  local extra="" lib ver
  for d in "${deps[@]}"; do
    read -r lib ver <<<"$d"
    extra+="\\n        $lib {:mvn/version \"$ver\"}"
  done
  # deps-new writes the :deps map on one line; append ours before its closing brace.
  sed -i "s|^ :deps {\(.*\)}\$| :deps {\1$extra}|" deps.edn
  for d in "${deps[@]}"; do
    grep -q "${d%% *} " deps.edn || { echo "Failed to add ${d%% *} to deps.edn" >&2; exit 1; }
  done
}

add_clj_kondo() {
  echo "Setting up clj-kondo..."
  mkdir -p .clj-kondo
  cat > .clj-kondo/config.edn <<'KONDO'
{:linters {:shadowed-var {:level :warning}}}
KONDO
  # Import lint configs that libraries ship (e.g. malli, reitit).
  clj-kondo --lint "$(clojure -Spath -A:test)" --dependencies --copy-configs --skip-lint
}

add_lambda() {
  echo "Adding AWS Lambda handler..."
  # The handler replaces the template's -main entry point and its failing placeholder test.
  rm -f "src/$ns_path.clj" "test/${ns_path}_test.clj"
  mkdir -p "src/$ns_path" "test/$ns_path" dev

  cat > "src/$ns_path/app.clj" <<CLJ
(ns $ns.app
  (:require [reitit.coercion.malli :as malli-coercion]
            [reitit.ring :as ring]
            [reitit.ring.coercion :as coercion]
            [reitit.ring.middleware.parameters :as parameters]))

(defn- hello [{{{who :name} :query} :parameters}]
  {:status 200
   :headers {"Content-Type" "text/plain; charset=utf-8"}
   :body (str "Hello, " who "!")})

(def router
  (ring/router
   [["/hello" {:get {:parameters {:query [:map [:name [:string {:min 1}]]]}
                     :handler hello}}]]
   {:data {:coercion malli-coercion/coercion
           :middleware [parameters/parameters-middleware
                        coercion/coerce-exceptions-middleware
                        coercion/coerce-request-middleware]}}))

;; Built at namespace load so SnapStart snapshots a ready handler.
(def app
  (ring/ring-handler router (ring/create-default-handler)))
CLJ

  cat > "src/$ns_path/lambda.clj" <<CLJ
(ns $ns.lambda
  (:gen-class :implements
              [com.amazonaws.services.lambda.runtime.RequestStreamHandler])
  (:require [paulbutcher.ring-lambda-adapter :refer [handle-request]]
            [$ns.app :refer [app]]))

(defn -handleRequest [_ is os _]
  (handle-request app is os))
CLJ

  cat > "test/$ns_path/app_test.clj" <<CLJ
(ns $ns.app-test
  (:require [clojure.test :refer [deftest is testing]]
            [$ns.app :as sut]))

(defn- get-req [uri query]
  (sut/app {:request-method :get :uri uri :query-string query :headers {}}))

(deftest hello-test
  (testing "greets by name"
    (let [{:keys [status body]} (get-req "/hello" "name=Clojure")]
      (is (= 200 status))
      (is (= "Hello, Clojure!" body))))
  (testing "rejects a missing name"
    (is (= 400 (:status (get-req "/hello" nil)))))
  (testing "unknown route"
    (is (= 404 (:status (get-req "/nope" nil))))))
CLJ

  cat > dev/user.clj <<CLJ
(ns user
  (:require [ring.adapter.jetty :as jetty]
            [$ns.app :refer [app]]))

(defn -main [& _]
  (jetty/run-jetty #'app {:port 8080 :host "0.0.0.0" :join? false}))
CLJ

  # Swap the template's -main aliases for a local dev server.
  sed -i '/^ :aliases$/,$d' deps.edn
  cat >> deps.edn <<'EDN'
 :aliases
 {:dev {:extra-paths ["dev"]
        :extra-deps {org.slf4j/slf4j-simple {:mvn/version "2.0.17"}
                     ring/ring-jetty-adapter {:mvn/version "1.15.6"}}
        :main-opts ["-m" "user"]}
  :build {:deps {io.github.clojure/tools.build {:mvn/version "0.10.14"}}
          :ns-default build}
  :test {:extra-paths ["test"]
         :extra-deps {io.github.cognitect-labs/test-runner {:git/tag "v0.5.1" :git/sha "dfb30dd"}}}}}
EDN

  cat > build.clj <<CLJ
(ns build
  (:refer-clojure :exclude [test])
  (:require [clojure.tools.build.api :as b]))

(def lib '$lib)
(def version "0.1.0-SNAPSHOT")
(def main '$ns.lambda)
(def class-dir "target/classes")

(defn test "Run all the tests." [opts]
  (let [basis    (b/create-basis {:aliases [:test]})
        cmds     (b/java-command
                  {:basis     basis
                   :main      'clojure.main
                   :main-args ["-m" "cognitect.test-runner"]})
        {:keys [exit]} (b/process cmds)]
    (when-not (zero? exit) (throw (ex-info "Tests failed" {}))))
  opts)

(defn- uber-opts [opts]
  (assoc opts
         :lib lib :main main
         :uber-file (format "target/%s-%s.jar" lib version)
         :basis (b/create-basis {})
         :class-dir class-dir
         :src-dirs ["src"]
         :ns-compile [main]
         :java-opts ["-Dclojure.compiler.direct-linking=true"]))

(defn uber "Build the uberjar without running tests." [opts]
  (b/delete {:path "target"})
  (let [opts (uber-opts opts)]
    (b/copy-dir {:src-dirs ["resources" "src"] :target-dir class-dir})
    (b/compile-clj opts)
    (b/uber opts))
  opts)

(defn ci "Run the tests, then build the uberjar." [opts]
  (test opts)
  (uber opts))
CLJ
}

add_deps
if $lambda; then add_lambda; fi
add_clj_kondo

echo "Done: $dir"
