(ns user
  (:require [ring.adapter.jetty :as jetty]
            [surt666.lambda-test :refer [app]]))

(defn -main [& _]
  (jetty/run-jetty #'app {:port 8080 :host "0.0.0.0" :join? false}))
