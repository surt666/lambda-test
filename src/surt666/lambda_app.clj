(ns surt666.lambda-app
  (:require [compojure.core :refer [defroutes GET]]
            [compojure.route :as route]
            [hiccup2.core :refer [html]]
            [ring.logger :refer [wrap-with-logger]]
            [ring.middleware.defaults :refer [site-defaults wrap-defaults]]
            [ring.middleware.params :refer [wrap-params]]))

;; Pre-render static HTML at namespace load time for SnapStart
(def index-html
  (str (html [:head [:title "HTMX Example"]
              [:script {:src "https://unpkg.com/htmx.org@2.0.4"}]]
             [:body [:h1 "HTMX Example"]
              [:div#greeting {:hx-get "/greet" :hx-trigger "load"}]])))

(def greet-html
  (str (html [:div "Hello, World!"])))

(defn index-page [] index-html)

(defn greet [] greet-html)

(defroutes app-routes
  (GET "/" [] (index-page))
  (GET "/greet" [] (greet))
  (route/not-found "Not Found"))

;; Build middleware stack at namespace load time
(def app
  (-> app-routes
      wrap-params
      (wrap-defaults site-defaults)
      wrap-with-logger))
