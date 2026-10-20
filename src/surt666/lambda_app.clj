(ns surt666.lambda-app
  (:require [hiccup2.core :refer [html]]
            [reitit.ring :as ring]
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

(defn- html-response [body]
  {:status 200
   :headers {"Content-Type" "text/html; charset=utf-8"}
   :body body})

(defn index-page [_] (html-response index-html))

(defn greet [_] (html-response greet-html))

(def app-routes
  (ring/ring-handler
   (ring/router
    [["/" {:get index-page}]
     ["/greet" {:get greet}]])
   (ring/create-default-handler
    {:not-found (constantly {:status 404 :headers {} :body "Not Found"})})))

;; Build middleware stack at namespace load time
(def app
  (-> app-routes
      wrap-params
      (wrap-defaults site-defaults)
      wrap-with-logger))

