(ns surt666.lambda
  (:gen-class :implements
              [com.amazonaws.services.lambda.runtime.RequestStreamHandler])
  (:require [paulbutcher.ring-lambda-adapter :refer [handle-request]]
            [surt666.lambda-test :refer [app]]))

(defn -handleRequest [_ is os _] (handle-request app is os))
