(ns surt666.lambda-test
  (:require [compojure.core :refer [defroutes GET]]
            [compojure.route :as route]
            [hiccup2.core :refer [html]]
            [ring.logger :refer [wrap-with-logger]]
            [ring.middleware.defaults :refer [site-defaults wrap-defaults]]
            [ring.middleware.params :refer [wrap-params]]))

(defn index-page
  []
  (str (html [:head [:title "HTMX Example"]
              [:script {:src "https://unpkg.com/htmx.org@2.0.4"}]]
             [:body [:h1 "HTMX Example"]
              [:div#greeting {:hx-get "/greet" :hx-trigger "load"}]])))

(defn greet [] (str (html [:div "Hello, World!"])))

(defroutes app-routes
  (GET "/" [] (index-page))
  (GET "/greet" [] (greet))
  (route/not-found "Not Found"))

(def app
  (-> app-routes
      wrap-params
      (wrap-defaults site-defaults)
      wrap-with-logger))
