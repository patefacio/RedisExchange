library bin.exch;

import 'package:ebisu_cpp/cpp.dart';
import 'package:logging/logging.dart';
import '../../lib/installation.dart';

final exch = lib('exch')
  ..namespace = namespace([ 'exch' ])
  ..headers = [
    header('exch')
    ..isApiHeader = true
    ..includes = [ 'cstdint', 'vector', 'utility', 'limits',
      'fcs/timestamp/timestamp.hpp' ]
    ..customBlocks = [ fcbEndNamespace ]
    ..forwardDecls = [
      forwardDecl('Order'),
    ]
    ..enums = [
      enum_('side')
      ..values = [ 'bid_side', 'ask_side' ],

      enum_('create_market_result')
      ..values = [
        'create_market_succeeded',
        'create_market_failed', ],

      enum_('submit_result')
      ..values = [
        'submit_succeeded',
        'submit_invalid_market',
        'submit_invalid_order_details' ],

      enum_('cancel_result')
      ..values = [
        'cancel_succeeded',
        'cancel_invalid_market',
        'cancel_invalid_order'
      ],

      enum_('replace_result')
      ..values = [
        'replace_succeeded',
        'replace_invalid_market',
        'replace_invalid_order',
        'replace_invalid_order_details',
      ],
    ]
    ..usings = [
      'Market_id_t = int32_t',
      'User_id_t = int64_t',
      'Price_t = int32_t',
      'Quantity_t = int32_t',
      'Order_id_t = int64_t',
      'Fill_id_t = int64_t',
      'Order_id_list_t = std::vector< Order_id_t >',
      'Order_list_t = std::vector< Order >',
      'Timestamp_t = fcs::timestamp::Timestamp_t',
      'Order_update_t = std::pair< Order_id_t, Order >',
      'Order_update_list_t = std::vector< Order_update_t >',
      'Req_id_t = int64_t',
    ],
    header('order_book')
    ..customBlocks = [ fcbBeginNamespace ]
    ..forwardDecls = [
      forwardDecl('Fill'),
    ]
    ..usings = [
      'Fill_list_t = std::vector<Fill>',
      'Price_list_t = std::vector<Price_t>',
    ]
    ..includes = [
      'sstream',
      'map',
      'vector',
      'functional',
      'fcs/utils/streamers/containers.hpp',
      'fcs/utils/streamers/table.hpp',
      'boost/range/adaptor/reversed.hpp',
    ]
    ..enums = [
      enum_('order_state')
      ..values = [ 'submitted', 'active', 'canceled', 'filled' ],
    ]
    ..classes = [

      class_('book_entry')
      ..struct = true
      ..streamable = true
      ..defaultCtor.useDefault = true
      ..memberCtors = [ memberCtor(['price', 'quantity']) ]
      ..members = [
        member('price')..type = 'Price_t'..cppAccess = public..noInit = true,
        member('quantity')..type = 'Quantity_t'..cppAccess = public..noInit = true,
      ],

      class_('market')
      ..struct = true
      ..memberCtors = [ memberCtor(['bid', 'ask']) ]
      ..streamable = true
      ..defaultCtor.useDefault = true
      ..members = [
        member('bid')..type = 'Book_entry'..cppAccess = public..noInit = true,
        member('ask')..type = 'Book_entry'..cppAccess = public..noInit = true,
      ],

      class_('order')
      ..immutable = true
      ..streamable = true
      ..serializers = [ cereal() ]
      ..customBlocks = [ clsPublic ]
      ..members = [
        member('order_id')..type = 'Order_id_t',
        member('timestamp')..type = 'Timestamp_t',
        member('side')..type = 'Side'..serializeInt = true,
        member('price')..type = 'Price_t',
        member('quantity')..type = 'Quantity_t',
      ],

      class_('managed_order')
      ..customBlocks = [ clsPublic, clsPostDecl ]
      ..streamable = true
      ..memberCtors = [ memberCtor([ 'order' ]) ]
      ..usingsPostDecl = [
        'Managed_order_list_t = std::vector< Managed_order >'
      ]
      ..members = [
        member('order')..type = 'Order'..noInit = true..isConst = true
        ..cppAccess = public..byRef = true,
        member('order_state')..type = 'Order_state'..init = 'Submitted_e'..cppAccess = public,
        member('filled')..type = 'Quantity_t'..init = 0..cppAccess = private,
      ],

      class_('fill')
      ..immutable = true
      ..streamable = true
      ..serializers = [ cereal(), dsv() ]
      ..customBlocks = [ clsPublic ]
      ..defaultCtor.useDefault = true
      ..members = [
        member('fill_id')..type = 'Fill_id_t',
        member('timestamp')..type = 'Timestamp_t',
        member('bid_id')..type = 'Order_id_t',
        member('ask_id')..type = 'Order_id_t',
        member('price')..type = 'Price_t',
        member('quantity')..type = 'Quantity_t',
      ],

      class_('order_book')
      ..customBlocks = [ clsPublic ]
      ..usesStreamers = true
      ..usings = [
        'Bid_compare_t = std::greater< Price_t >',
        'Bids_t = std::map< Price_t, Managed_order_list_t, Bid_compare_t >',
        'Asks_t = std::map< Price_t, Managed_order_list_t >',
      ]
      ..members = [
        member('bids')..type = 'Bids_t',
        member('asks')..type = 'Asks_t',
        member('next_fill_id')..init = 0,
      ],

    ],
    header('market_exch')
    ..includes = [
      'exch/order_book.hpp',
      'fcs/utils/streamers/containers.hpp',
    ]
    ..enums = [
    ]
    ..classes = [
      class_('market_config')
      ..immutable = true
      ..streamable = true
      ..members = [
        member('name')..type = 'std::string',
        member('start_time')..type = 'Timestamp_t',
        member('end_time')..type = 'Timestamp_t',
        member('decimal_shift')..type = 'int',
        member('tick_size')..type = 'int',
      ],
      class_('market_exchange')
      ..descr = 'Responsible for the exchange of a single market (e.g. one market id)'
      ..customBlocks = [ clsPublic ]
      ..usings = [
      ]
      ..memberCtors = [ memberCtor([ 'market_config', 'market_id' ] )]
      ..members = [
        member('market_config')..type = 'Market_config'..noInit = true..byRef = true,
        member('market_id')..type = 'Market_id_t'..isConst = true,
        member('next_order_id')..init = 0,

        member('order_book')..type = 'Order_book',
        member('fills')..type = 'Fill_list_t'..init = 32,
        member('prices_affected')..type = 'Price_list_t'..init = 32,
        member('dead_orders')..type = 'Managed_order_list_t',
        member('net_volume')..type = 'Quantity_t',
      ],
    ],
    header('requests')
    ..descr = 'Requests types available to clients of the exchange'
    ..includes = [ 'fcs/timestamp/conversion.hpp', ]
    ..classes = [
      ////////////////////////////////////////////////////////////
      // Requests/Responses
      ////////////////////////////////////////////////////////////
      class_('create_market_req')
      ..defaultCtor.useDefault = true
      ..streamable = true
      ..serializers = [ cereal(), dsv() ]
      ..immutable = true
      ..members = [
        member('req_id')..type = 'Req_id_t',
        member('user_id')..type = 'User_id_t',
        member('name')..type = 'std::string',
        member('start_time')..type = 'Timestamp_t',
        member('end_time')..type = 'Timestamp_t',
        member('decimal_shift')..type = 'int',
        member('tick_size')..type = 'int',
      ],
      class_('create_market_resp')
      ..defaultCtor.useDefault = true
      ..streamable = true
      ..serializers = [ cereal() ]
      ..immutable = true
      ..members = [
        member('req_id')..type = 'Req_id_t',
        member('user_id')..type = 'User_id_t',
        member('market_id')..type = 'Market_id_t',
        member('result')..type = 'Create_market_result',
      ],

      class_('submit_req')
      ..defaultCtor.useDefault = true
      ..streamable = true
      ..serializers = [ cereal(), dsv() ]
      ..immutable = true
      ..members = [
        member('req_id')..type = 'Req_id_t',
        member('user_id')..type = 'User_id_t',
        member('market_id')..type = 'Market_id_t',
        member('side')..type = 'Side'..serializeInt = true,
        member('price')..type = 'Price_t',
        member('quantity')..type = 'Quantity_t',
      ],
      class_('submit_resp')
      ..defaultCtor.useDefault = true
      ..streamable = true
      ..serializers = [ cereal() ]
      ..immutable = true
      ..members = [
        member('req_id')..type = 'Req_id_t',
        member('user_id')..type = 'User_id_t',
        member('market_id')..type = 'Market_id_t',
        member('order_id')..type = 'Order_id_t',
        member('result')..type = 'Submit_result',
      ],

      class_('cancel_req')
      ..defaultCtor.useDefault = true
      ..streamable = true
      ..serializers = [ cereal(), dsv() ]
      ..immutable = true
      ..members = [
        member('req_id')..type = 'Req_id_t',
        member('user_id')..type = 'User_id_t',
        member('market_id')..type = 'Market_id_t',
        member('order_id')..type = 'Order_id_t',
      ],
      class_('cancel_resp')
      ..defaultCtor.useDefault = true
      ..streamable = true
      ..serializers = [ cereal() ]
      ..immutable = true
      ..members = [
        member('req_id')..type = 'Req_id_t',
        member('user_id')..type = 'User_id_t',
        member('market_id')..type = 'Market_id_t',
        member('order_id')..type = 'Order_id_t',
        member('result')..type = 'Cancel_result',
      ],

      class_('replace_req')
      ..defaultCtor.useDefault = true
      ..streamable = true
      ..serializers = [ cereal(), dsv() ]
      ..immutable = true
      ..members = [
        member('req_id')..type = 'Req_id_t',
        member('user_id')..type = 'User_id_t',
        member('market_id')..type = 'Market_id_t',
        member('order_id')..type = 'Order_id_t',
        member('price')..type = 'Price_t',
        member('quantity')..type = 'Quantity_t',
      ],
      class_('replace_resp')
      ..defaultCtor.useDefault = true
      ..streamable = true
      ..serializers = [ cereal() ]
      ..immutable = true
      ..members = [
        member('req_id')..type = 'Req_id_t',
        member('user_id')..type = 'User_id_t',
        member('market_id')..type = 'Market_id_t',
        member('canceled_order_id')..type = 'Order_id_t',
        member('order_id')..type = 'Order_id_t',
        member('result')..type = 'Replace_result',
      ],
    ],
    header('events')
    ..descr = 'Events published by the exchange'
    ..classes = [
      ////////////////////////////////////////////////////////////
      // Events
      ////////////////////////////////////////////////////////////
      class_('market_created_evt')
      ..streamable = true
      ..serializers = [ cereal() ]
      ..immutable = true
      ..members = [
        member('market_id')..type = 'Market_id_t',
      ],

      class_('top_of_book_evt')
      ..streamable = true
      ..serializers = [ cereal() ]
      ..immutable = true
      ..members = [
        member('market_id')..type = 'Market_id_t',
      ],
      class_('book_update_evt')
      ..streamable = true
      ..serializers = [ cereal() ]
      ..immutable = true
      ..members = [
        member('market_id')..type = 'Market_id_t',
        member('side')..type = 'Side'..serializeInt = true,
        member('price')..type = 'Price_t',
        member('quantity')..type = 'Quantity_t',
        member('top_price')..type = 'Price_t',
      ],
      class_('trade_evt')
      ..streamable = true
      ..serializers = [ cereal() ]
      ..immutable = true
      ..members = [
        member('market_id')..type = 'Market_id_t',
        member('side')..type = 'Side'..serializeInt = true,
        member('quantity')..type = 'Quantity_t',
        member('price')..type = 'Price_t',
        member('net_volume')..type = 'Quantity_t',
      ],
    ],

    header('interfaces')
    ..includes = [ 'exch/requests.hpp', 'exch/events.hpp',
      'boost/function.hpp', ]
    ..usings = [
      'Create_market_handler_t = boost::function< void(const Create_market_req & req) >',
      'Submit_handler_t = boost::function< void(const Submit_req & req) >',
      'Cancel_handler_t = boost::function< void(const Cancel_req & req) >',
      'Replace_handler_t = boost::function< void(const Replace_req & req) >',
      'Halt_handler_t = boost::function< void() >',
    ]
    ..descr = '''
Includes abstract interfaces used by the exchange to decouple interface from implementation
'''
    ..classes = [
      class_('request_listener')
      ..descr = 'Listens for requests (submit, cancel, replace,...) from clients'
      ..dtor.abstract = true
      ..customBlocks = [ clsPublic ],

      class_('request_persister')
      ..descr = 'Persists requests (submit, cancel, replace,...) and results'
      ..dtor.abstract = true
      ..customBlocks = [ clsPublic ],

      class_('market_publisher')
      ..descr = 'Publishes market events (fill, top_of_book,...)'
      ..dtor.abstract = true
      ..customBlocks = [ clsPublic ],
    ],

    header('exchange')
    ..includes = [
      'exch/market_exch.hpp', 'exch/requests.hpp',
      'exch/events.hpp', 'exch/interfaces.hpp',
    ]
    ..classes = [

      class_('exchange')
      ..descr = '''
Manages multiple markets. Requests come from the listener, to which
this exchange subscribes. Those requests are persisted and turned into
Market_exchange type objects (e.g. order) which are forwarded to the
appropriate Market_exchange for handling. Responses from the
Market_exchange instances are then persisted and used to create and
publish events using the Market_publisher. An example publisher might
serialize the responses to Json and post via redis - but that is an
implementation detail from the perspective of this class.'''
      ..includeTest = true
      ..customBlocks = [ clsPublic, clsPrivate ]
      ..memberCtors = [
        memberCtor([
          'bootstrap_listener', 'request_listener', 'request_persister', 'market_publisher',
        ])..customLabel = 'from_args'
      ]
      ..usings = [
        'Market_exchange_naked_ptr = Market_exchange *',
        'Market_exchange_ptr = std::unique_ptr< Market_exchange >',
        'Market_exchange_map_t = std::map< Market_id_t, Market_exchange_ptr >',
      ]
      ..members = [
        member('bootstrap_listener')..type = 'Request_listener'..refType = ref,
        member('request_listener')..type = 'Request_listener'..refType = ref,
        member('request_persister')..type = 'Request_persister'..refType = ref,
        member('market_publisher')..type = 'Market_publisher'..refType = ref,
        member('market_exchanges')..type = 'Market_exchange_map_t',
        member('is_live')
        ..descr = 'Indicates bootstrapping is complete and new commands should be saved and responses published'
        ..init = false,
        member('next_market_id')..init = 0,
      ],
    ],

    header('redis_support')
    ..constExprs = [
      constExpr('m_req_key', 'EX_REQ:M'),
      constExpr('s_req_key', 'EX_REQ:S'),
      constExpr('c_req_key', 'EX_REQ:C'),
      constExpr('r_req_key', 'EX_REQ:R'),
      constExpr('h_req_key', 'EX_REQ:H'),
      constExpr('cmd_key', 'CMD'),
    ]
    ..includes = [
      'exch/order_book.hpp',
      'exch/interfaces.hpp',
      'sstream',
      'functional',
      'redisclient/redisclient.h',
    ]
    ..usings = [
      'Req_func_t = boost::function< void(const std::string & request) >',
    ]
    ..descr = '''
Uses redis pub/sub as means to accept requests destined to a
Market_exchange and publish responses destined for clients.'''
    ..customBlocks = [ fcbBeginNamespace ]
    ..classes = [

      class_('redis_listener')
      ..includeTest = true
      ..descr = '''
Subscribes to client requests on redis pub/sub channels'''
      ..customBlocks = [ clsPublic ]
      ..memberCtors = [ memberCtor(['redis_client']) ]
      ..bases = [ base('Request_listener') ]
      ..members = [
        member('redis_client')..type = 'RedisClient'..refType = ref,
        member('m_handle')..type = 'RedisClient::Handle'..initText = '0',
        member('s_handle')..type = 'RedisClient::Handle'..initText = '0',
        member('c_handle')..type = 'RedisClient::Handle'..initText = '0',
        member('r_handle')..type = 'RedisClient::Handle'..initText = '0',
        member('h_handle')..type = 'RedisClient::Handle'..initText = '0',
        member('create_market_handler')..type = 'Create_market_handler_t',
        member('submit_handler')..type = 'Submit_handler_t',
        member('cancel_handler')..type = 'Cancel_handler_t',
        member('replace_handler')..type = 'Replace_handler_t',
        member('halt_handler')..type = 'Halt_handler_t',
        // member('req_key')..init = 'EX_REQ:*'
        // ..type = 'char const*'..isStatic = true..isConstExpr = true,
      ],

      class_('redis_bootstrap_listener')
      ..descr = '''
Loads all saved commands from persistent storage at startup, effectively turning
previously saved commands into a stream of commands for a subscriber (i.e. an
exchange) to use at startup to process all messages to get to state just prior
to last message before last shutdown.
'''
      ..customBlocks = [ clsPublic ]
      ..memberCtors = [ memberCtor(['redis_client']) ]
      ..bases = [ base('Request_listener') ]
      ..members = [
        member('redis_client')..type = 'RedisClient'..refType = ref,
      ],


      class_('redis_persister')
      ..customBlocks = [ clsPublic, clsPrivate ]
      ..bases = [ base('Request_persister') ]
      ..memberCtors = [ memberCtor(['redis_client']) ]
      ..members = [
        member('redis_client')..type = 'RedisClient'..refType = ref,
      ],

      class_('redis_publisher')
      ..descr = '''
Implements the Market_publisher interface using redis as pub/sub
middleware'''
      ..memberCtors = [ memberCtor(['redis_client']) ]
      ..customBlocks = [ clsPublic, clsPrivate ]
      ..bases = [ base('Market_publisher') ]
      ..members = [
        member('redis_client')..type = 'RedisClient'..refType = ref,
        member('resp_key')..init = 'EX_RESP'..type = 'char const*'..isStatic = true..isConstExpr = true,
        member('event_key')..init = 'EX_EVENT'..type = 'char const*'..isStatic = true..isConstExpr = true,
      ],

    ],

  ];

addItems() => installation.addLibs([exch]);

main() {
  Logger.root
    ..onRecord.listen((LogRecord r) =>
        print("${r.loggerName} [${r.level}]:\t${r.message}"))
    ..level = Level.WARNING;
  addItems();
  installation.generate();
}
