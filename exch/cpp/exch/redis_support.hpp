#ifndef __EXCH_REDIS_SUPPORT_HPP__
#define __EXCH_REDIS_SUPPORT_HPP__

#include "exch/exch.hpp"
#include "exch/interfaces.hpp"
#include "exch/order_book.hpp"
#include "hiredis/async.h"
#include <chrono>
#include <functional>
#include <sstream>

namespace exch {
// custom <FcbBeginNamespace redis_support>

std::string redis_key(std::string const& market_id, Order const& order) {
  std::string result;
  result.reserve(32);  // 11 for market id + 1 for colon + 11 order id up
  // to power of 2
  result.append(market_id);
  result.push_back(':');
  result.append(boost::lexical_cast<std::string>(order.order_id()));
  return result;
}

// end <FcbBeginNamespace redis_support>

using Req_func_t = boost::function<void(const std::string& request)>;

/**
 Subscribes to client requests on redis pub/sub channels
*/
class Redis_listener : public Request_listener {
 public:
  Redis_listener(redisAsyncContext& context) : context_{context} {}

  // custom <ClsPublic Redis_listener>

  static void dispatch(redisAsyncContext* context, void* r, void* priv) {
    if (r == NULL) return;
    redisReply* reply = {static_cast<redisReply*>(r)};
    Redis_listener* listener{static_cast<Redis_listener*>(priv)};
    if (strcmp(reply->element[0]->str, "psubscribe") != 0) {
      listener->dispatcher(reply->element[2]->str, reply->element[3]->str);
    }
  }

  virtual void subscribe(Create_market_handler_t create_market_handler,
                         Submit_handler_t submit_handler,
                         Cancel_handler_t cancel_handler,
                         Replace_handler_t replace_handler,
                         Market_details_handler_t market_details_handler,
                         Log_handler_t log_handler,
                         Halt_handler_t halt_handler) {

    create_market_handler_ = create_market_handler;
    submit_handler_ = submit_handler;
    cancel_handler_ = cancel_handler;
    replace_handler_ = replace_handler;
    market_details_handler_ = market_details_handler;
    log_handler_ = log_handler;
    halt_handler_ = halt_handler;

    redisAsyncCommand(&context_, dispatch, this, "PSUBSCRIBE EX_REQ:*");
  }

  void dispatcher(char const* channel, char const* message) {
    // Switch on character
    // EX_REQ:*
    // 01234567
    switch (channel[7]) {
      case 'M':
        create_market(message);
        break;
      case 'S':
        submit(message);
        break;
      case 'C':
        cancel(message);
        break;
      case 'R':
        replace(message);
        break;
      case 'L':
        log(message);
        break;
      case 'D':
        market_details(message);
        break;
      case 'H':
        halt();
        break;
      default:
        throw std::logic_error(std::string("unexpected message type: ") +
                               message);
    }
  }

  virtual void unsubscribe() {
    // TODO:
  }

  void create_market(std::string const& command) {
    Create_market_req req;
    std::istringstream in{command};
    req.serialize_from_json(in);
    create_market_handler_(req);
  }

  void submit(std::string const& command) {
    Submit_req req;
    std::istringstream in{command};
    req.serialize_from_json(in);
    submit_handler_(req);
  }

  void cancel(std::string const& command) {
    Cancel_req req;
    std::istringstream in{command};
    req.serialize_from_json(in);
    cancel_handler_(req);
  }

  void replace(std::string const& command) {
    Replace_req req;
    std::istringstream in{command};
    req.serialize_from_json(in);
    replace_handler_(req);
  }

  void market_details(std::string const& command) {
    Market_details_req req;
    std::istringstream in{command};
    req.serialize_from_json(in);
    market_details_handler_(req);
  }

  void log(std::string const& command) {
    Log_req req;
    std::istringstream in{command};
    req.serialize_from_json(in);
    log_handler_(req);
  }

  void halt() {
    std::cout << "halt req " << std::endl;
    halt_handler_();
  }

  virtual ~Redis_listener() { unsubscribe(); }

  // end <ClsPublic Redis_listener>

 private:
  redisAsyncContext& context_;
  Create_market_handler_t create_market_handler_{};
  Submit_handler_t submit_handler_{};
  Cancel_handler_t cancel_handler_{};
  Replace_handler_t replace_handler_{};
  Log_handler_t log_handler_{};
  Market_details_handler_t market_details_handler_{};
  Halt_handler_t halt_handler_{};
};

/**
 Loads all saved commands from persistent storage at startup, effectively
 turning
 previously saved commands into a stream of commands for a subscriber (i.e. an
 exchange) to use at startup to process all messages to get to state just prior
 to last message before last shutdown.

*/
class Redis_bootstrap_listener : public Request_listener {
 public:
  Redis_bootstrap_listener(redisContext& context) : context_{context} {}

  // custom <ClsPublic Redis_bootstrap_listener>

  virtual void subscribe(Create_market_handler_t create_market_handler,
                         Submit_handler_t submit_handler,
                         Cancel_handler_t cancel_handler,
                         Replace_handler_t replace_handler,
                         Market_details_handler_t market_details_handler,
                         Log_handler_t log_handler,
                         Halt_handler_t halt_handler) override {

    redisReply* reply{
        static_cast<redisReply*>(redisCommand(&context_, "LRANGE CMD 0 -1"))};

    if (reply != nullptr) {
      using namespace std::chrono;
      auto start = system_clock::now();

      for (int i = 0; i < reply->elements; ++i) {
        std::string cmdStr{reply->element[i]->str};

        switch (cmdStr[0]) {
          case 'M': {
            Create_market_req req;
            req.serialize_from_dsv(cmdStr.substr(2));
            create_market_handler(req);
          } break;
          case 'S': {
            Submit_req req;
            req.serialize_from_dsv(cmdStr.substr(2));
            submit_handler(req);
          } break;
          case 'C': {
            Cancel_req req;
            req.serialize_from_dsv(cmdStr.substr(2));
            cancel_handler(req);
          } break;
          case 'R': {
            Replace_req req;
            req.serialize_from_dsv(cmdStr.substr(2));
            replace_handler(req);
          } break;
          default:
            std::ostringstream msg;
            msg << "Can not bootstrap: Invalid command found " << cmdStr;
            throw std::logic_error(msg.str());
        }
      }

      freeReplyObject(reply);

      auto duration =
          duration_cast<milliseconds>(std::chrono::system_clock::now() - start);

      std::cout << "Processed " << reply->elements
                << " existing commands in:" << duration.count() << " ms\n";
    }
  }

  virtual void unsubscribe() override {}

  // end <ClsPublic Redis_bootstrap_listener>

 private:
  redisContext& context_;
};

class Redis_persister : public Request_persister {
 public:
  Redis_persister(redisAsyncContext& context) : context_{context} {}

  // custom <ClsPublic Redis_persister>

  virtual void persist(Create_market_req const& req) override {
    _persist(req, 'M');
  }

  virtual void persist(Submit_req const& req) override { _persist(req, 'S'); }

  virtual void persist(Cancel_req const& req) override { _persist(req, 'C'); }

  virtual void persist(Replace_req const& req) override { _persist(req, 'R'); }

  virtual void persist(Fill const& fill) override {
    fmt::MemoryWriter w;
    w << fill.serialize_to_dsv();
    redisAsyncCommand(&context_, nullptr, nullptr, "RPUSH FILLS %s",
                      w.str().c_str());
    // TODO: implement strategy on failed push
  }

  // end <ClsPublic Redis_persister>

 private:
  // custom <ClsPrivate Redis_persister>

  template <typename T>
  void _persist(T const& item, char cmd) {
    fmt::MemoryWriter w;
    w << cmd << ':' << item.serialize_to_dsv();
    redisAsyncCommand(&context_, nullptr, nullptr, "RPUSH CMD %s",
                      w.str().c_str());
    // TODO: implement strategy on failed push
  }

  // end <ClsPrivate Redis_persister>

  redisAsyncContext& context_;
};

/**
 Implements the Market_publisher interface using redis as pub/sub
 middleware
*/
class Redis_publisher : public Market_publisher {
 public:
  Redis_publisher(redisAsyncContext& context) : context_{context} {}

  // custom <ClsPublic Redis_publisher>

  virtual void publish(Create_market_resp const& resp) override {
    _publish(CREATE_RESP_KEY, resp);
  }

  virtual void publish(Submit_resp const& resp) override {
    _publish(SUBMIT_RESP_KEY, resp);
  }

  virtual void publish(Cancel_resp const& resp) override {
    _publish(CANCEL_RESP_KEY, resp);
  }

  virtual void publish(Replace_resp const& resp) override {
    _publish(REPLACE_RESP_KEY, resp);
  }

  virtual void publish(Market_details_resp const& resp) override {
    _publish(MARKET_DETAILS_RESP_KEY, resp);
  }

  virtual void publish(Market_created_evt const& evt) override {
    _publish(MARKET_CREATED_EVENT_KEY, evt);
  }

  virtual void publish(Top_of_book_evt const& evt) override {
    _publish(TOP_EVENT_KEY, evt);
  }

  virtual void publish(Book_update_evt const& evt) override {
    _publish(BOOK_EVENT_KEY, evt);
  }

  virtual void publish(Fill const& fill) override {
    _publish(FILL_EVENT_KEY, fill);
  }

  // end <ClsPublic Redis_publisher>

 private:
  // custom <ClsPrivate Redis_publisher>

  template <typename T>
  void _publish(char const* key, T const& item) {
    std::ostringstream out;
    item.serialize_to_json(out);
    redisAsyncCommand(&context_, nullptr, nullptr, "PUBLISH %s %s", key,
                      out.str().c_str());
  }

  // end <ClsPrivate Redis_publisher>

  redisAsyncContext& context_;
  static constexpr char const* CREATE_RESP_KEY{"EX_RESP:M"};
  static constexpr char const* SUBMIT_RESP_KEY{"EX_RESP:S"};
  static constexpr char const* CANCEL_RESP_KEY{"EX_RESP:C"};
  static constexpr char const* REPLACE_RESP_KEY{"EX_RESP:R"};
  static constexpr char const* MARKET_DETAILS_RESP_KEY{"EX_RESP:D"};
  static constexpr char const* MARKET_CREATED_EVENT_KEY{"EX_EVT:M"};
  static constexpr char const* TOP_EVENT_KEY{"EX_EVT:T"};
  static constexpr char const* BOOK_EVENT_KEY{"EX_EVT:B"};
  static constexpr char const* FILL_EVENT_KEY{"EX_EVT:F"};
};

}  // namespace exch
#endif  // __EXCH_REDIS_SUPPORT_HPP__
