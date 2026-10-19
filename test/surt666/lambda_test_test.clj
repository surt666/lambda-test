(ns surt666.lambda-test-test
  (:require [clojure.string :as str]
            [clojure.test :refer [deftest is testing]]
            [surt666.lambda-app :as sut]))

(defn- get-req [uri]
  (sut/app {:request-method :get :uri uri :headers {}}))

(deftest routes-test
  (testing "index page"
    (let [{:keys [status body]} (get-req "/")]
      (is (= 200 status))
      (is (str/includes? body "HTMX Example"))))
  (testing "greet fragment"
    (let [{:keys [status body]} (get-req "/greet")]
      (is (= 200 status))
      (is (str/includes? body "Hello, World!"))))
  (testing "unknown route"
    (is (= 404 (:status (get-req "/nope"))))))
