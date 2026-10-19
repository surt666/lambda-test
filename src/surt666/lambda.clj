(ns surt666.lambda
  (:gen-class :implements
              [com.amazonaws.services.lambda.runtime.RequestStreamHandler])
  (:require [cognitect.aws.client.api :as aws]
            [paulbutcher.ring-lambda-adapter :refer [handle-request]]
            [surt666.lambda-app :refer [app]]))

;; Delay DynamoDB client initialization until after SnapStart restore
;; HTTP clients and connection pools should NOT be in the snapshot
(def ddb-client
  (delay (aws/client {:api :dynamodb})))

;; Prime the application during initialization (before SnapStart snapshot)
;; Keep this minimal - only load classes, avoid creating I/O resources
(defn- prime-application
  "Warm up the application by loading classes before snapshot"
  []
  (try
    ;; Just reference the app to force middleware stack evaluation
    ;; Don't actually call it - that creates too much state
    (when app :loaded)

    ;; Force AWS SDK namespace loading without creating HTTP clients
    (require 'cognitect.aws.protocols.rest-json)

    (catch Exception _
      ;; Ignore errors during priming
      nil)))

;; Run initialization eagerly when namespace loads (before SnapStart snapshot)
(prime-application)

(defn -handleRequest [_ is os _]
  (handle-request app is os))
