import 'dart:async';

import 'package:chopper/src/annotations.dart';
import 'package:chopper/src/authenticator.dart';
import 'package:chopper/src/chain/call.dart';
import 'package:chopper/src/constants.dart';
import 'package:chopper/src/converters.dart';
import 'package:chopper/src/devtools/devtools.dart';
import 'package:chopper/src/devtools/models/call_info.dart';
import 'package:chopper/src/devtools/models/client_info.dart';
import 'package:chopper/src/devtools/models/request_info.dart';
import 'package:chopper/src/devtools/models/response_info.dart';
import 'package:chopper/src/interceptors/interceptor.dart';
import 'package:chopper/src/request.dart';
import 'package:chopper/src/response.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

/// ChopperClient is the main class of the Chopper API.
///
/// It manages registered services, encodes and decodes data, and intercepts
/// requests and responses.
base class ChopperClient {
  /// Base URL of each request of the registered services.
  /// E.g., the hostname of your service.
  final Uri baseUrl;

  /// The [http.Client] used to make network calls.
  final http.Client httpClient;

  /// The [Converter] that handles request and response transformation before
  /// the request and response interceptors are called respectively.
  final Converter? converter;

  /// The [Authenticator] that can provide reactive authentication for a
  /// request.
  final Authenticator? authenticator;

  /// The [ErrorConverter] that handles response transformation before the
  /// response interceptors are called, but only on error responses
  /// (statusCode < 200 || statusCode >= 300\).
  final ErrorConverter? errorConverter;

  late final Map<Type, ChopperService> _services;
  late final List<Interceptor> interceptors;
  final StreamController<Request> _requestController =
      StreamController<Request>.broadcast();
  final StreamController<Response> _responseController =
      StreamController<Response>.broadcast();

  final bool _clientIsInternal;
  late final String _clientId = Uuid().v1();
  late final ChopperDevTools? devTools = ChopperDevTools.instance;

  /// Creates and configures a [ChopperClient].
  ///
  /// The base URL of each request of the registered services can be defined
  /// with the [baseUrl] parameter.
  ///  E.g., the hostname of your service.
  ///  If not provided, a empty default [Uri] will be used.
  ///
  /// A custom HTTP client can be passed as the [client] parameter to be used
  /// with the created [ChopperClient].
  /// If not provided, a default [http.Client] will be used.
  ///
  /// [ChopperService]s can be added to the client with the [services] parameter.
  /// See the [ChopperApi] annotation to learn more about creating services.
  ///
  /// ```dart
  /// final chopper = ChopperClient(
  ///   baseUrl: Uri.parse('localhost:8000'),
  ///   services: [
  ///     // Add a generated service
  ///     TodosListService.create()
  ///   ],
  /// );
  /// ```
  ///
  /// [Interceptor]s can be added to the client
  /// with the [interceptors] parameter.
  ///
  /// See [HttpLoggingInterceptor], [HeadersInterceptor], [CurlInterceptor]
  ///
  /// ```dart
  /// final chopper = ChopperClient(
  ///   ...
  ///   interceptors: [
  ///     HttpLoggingInterceptor(),
  ///   ]
  /// );
  /// ```
  ///
  /// [Converter]s can be added to the client with the [converter]
  /// parameter.
  /// [Converter]s are used to convert the body of requests and responses to and
  /// from the HTTP format.
  ///
  /// A different converter can be used to handle error responses
  /// (when [Response.isSuccessful] == false)) with tche [errorConverter] parameter.
  ///
  /// See [Converter], [JsonConverter]
  ///
  /// ```dart
  /// final chopper = ChopperClient(
  ///     ...
  ///     converter: JsonConverter(),
  ///     errorConverter: JsonConverter(),
  ///   );
  /// ```
  ChopperClient({
    Uri? baseUrl,
    http.Client? client,
    this.interceptors = const [],
    this.authenticator,
    this.converter,
    this.errorConverter,
    Iterable<ChopperService>? services,
  })  : assert(
          baseUrl == null || !baseUrl.hasQuery,
          'baseUrl should not contain query parameters. '
          'Use a request interceptor to add default query parameters',
        ),
        baseUrl = baseUrl ?? Uri(),
        httpClient = client ?? http.Client(),
        _clientIsInternal = client == null {
    _services = <Type, ChopperService>{
      for (final ChopperService service in services?.toSet() ?? [])
        service.definitionType: service..client = this
    };
    _postInfo();
  }

  /// Retrieve any service included in the [ChopperClient]
  ///
  /// ```dart
  /// final chopper = ChopperClient(
  ///   baseUrl: Uri.parse('localhost:8000'),
  ///   services: [
  ///     // Add a generated service
  ///     TodosListService.create()
  ///   ],
  /// );
  ///
  /// final todoService = chopper.getService<TodosListService>();
  /// ```
  ServiceType getService<ServiceType extends ChopperService>() {
    if (ServiceType == dynamic || ServiceType == ChopperService) {
      throw Exception(
        'Service type should be provided, `dynamic` is not allowed.',
      );
    }
    final ChopperService? service = _services[ServiceType];
    if (service == null) {
      throw Exception("Service of type '$ServiceType' not found.");
    }

    return service as ServiceType;
  }

  /// Sends a pre-build [Request], applying all provided [Interceptor]s and
  /// [Converter]s.
  ///
  /// [BodyType] should be the expected type of the response body
  /// (e.g., `String` or `CustomObject)`.
  ///
  /// If `BodyType` is a `List` or a `BuiltList`, [InnerType] should be type of the
  /// generic parameter (e.g., `convertResponse<List<CustomObject>, CustomObject>(response)`).
  ///
  /// ```dart
  /// Response<List<CustomObject>> res = await send<List<CustomObject>, CustomObject>(request);
  /// ````
  Future<Response<BodyType>> send<BodyType, InnerType>(
    Request request, {
    ConvertRequest? requestConverter,
    ConvertResponse<BodyType>? responseConverter,
  }) async {
    late final Request finalizedRequest;
    final call = Call(
      request: request,
      client: this,
      requestCallback: (Request request) {
        _requestController.add(request);
        finalizedRequest = request;
      },
    );

    final response = await call.execute<BodyType, InnerType>(
      requestConverter,
      responseConverter,
    );

    _responseController.add(response);

    _addCall(call, finalizedRequest, response);

    return response;
  }

  /// Makes a HTTP GET request using the [send] function.
  Future<Response<BodyType>> get<BodyType, InnerType>(
    Uri url, {
    Map<String, String> headers = const {},
    Uri? baseUrl,
    Map<String, dynamic> parameters = const {},
    dynamic body,
  }) =>
      send<BodyType, InnerType>(
        Request(
          HttpMethod.Get,
          url,
          baseUrl ?? this.baseUrl,
          body: body,
          headers: headers,
          parameters: parameters,
        ),
      );

  /// Makes a HTTP POST request using the [send] function
  Future<Response<BodyType>> post<BodyType, InnerType>(
    Uri url, {
    dynamic body,
    List<PartValue> parts = const [],
    Map<String, String> headers = const {},
    Map<String, dynamic> parameters = const {},
    bool multipart = false,
    Uri? baseUrl,
  }) =>
      send<BodyType, InnerType>(
        Request(
          HttpMethod.Post,
          url,
          baseUrl ?? this.baseUrl,
          body: body,
          parts: parts,
          headers: headers,
          parameters: parameters,
          multipart: multipart,
        ),
      );

  /// Makes a HTTP PUT request using the [send] function.
  Future<Response<BodyType>> put<BodyType, InnerType>(
    Uri url, {
    dynamic body,
    List<PartValue> parts = const [],
    Map<String, String> headers = const {},
    Map<String, dynamic> parameters = const {},
    bool multipart = false,
    Uri? baseUrl,
  }) =>
      send<BodyType, InnerType>(
        Request(
          HttpMethod.Put,
          url,
          baseUrl ?? this.baseUrl,
          body: body,
          parts: parts,
          headers: headers,
          parameters: parameters,
          multipart: multipart,
        ),
      );

  /// Makes a HTTP PATCH request using the [send] function.
  Future<Response<BodyType>> patch<BodyType, InnerType>(
    Uri url, {
    dynamic body,
    List<PartValue> parts = const [],
    Map<String, String> headers = const {},
    Map<String, dynamic> parameters = const {},
    bool multipart = false,
    Uri? baseUrl,
  }) =>
      send<BodyType, InnerType>(
        Request(
          HttpMethod.Patch,
          url,
          baseUrl ?? this.baseUrl,
          body: body,
          parts: parts,
          headers: headers,
          parameters: parameters,
          multipart: multipart,
        ),
      );

  /// Makes a HTTP DELETE request using the [send] function.
  Future<Response<BodyType>> delete<BodyType, InnerType>(
    Uri url, {
    Map<String, String> headers = const {},
    Map<String, dynamic> parameters = const {},
    Uri? baseUrl,
  }) =>
      send<BodyType, InnerType>(
        Request(
          HttpMethod.Delete,
          url,
          baseUrl ?? this.baseUrl,
          headers: headers,
          parameters: parameters,
        ),
      );

  /// Makes a HTTP HEAD request using the [send] function.
  Future<Response<BodyType>> head<BodyType, InnerType>(
    Uri url, {
    Map<String, String> headers = const {},
    Map<String, dynamic> parameters = const {},
    Uri? baseUrl,
  }) =>
      send<BodyType, InnerType>(
        Request(
          HttpMethod.Head,
          url,
          baseUrl ?? this.baseUrl,
          headers: headers,
          parameters: parameters,
        ),
      );

  /// Makes a HTTP OPTIONS request using the [send] function.
  Future<Response<BodyType>> options<BodyType, InnerType>(
    Uri url, {
    Map<String, String> headers = const {},
    Map<String, dynamic> parameters = const {},
    Uri? baseUrl,
  }) =>
      send<BodyType, InnerType>(
        Request(
          HttpMethod.Options,
          url,
          baseUrl ?? this.baseUrl,
          headers: headers,
          parameters: parameters,
        ),
      );

  /// Disposes this [ChopperClient] to clean up memory.
  ///
  /// **Warning**: If a custom [http.Client] was provided while creating this `ChopperClient`,
  /// this method ***will not*** close it. In that case, closing the client is
  /// its creator's responsibility.
  @mustCallSuper
  void dispose() {
    _requestController.close();
    _responseController.close();
    _services.clear();

    if (_clientIsInternal) {
      httpClient.close();
    }
  }

  /// A stream of processed [Request]s, as in after all [Converter]s, and
  /// [Interceptor]s have been run.
  Stream<Request> get onRequest => _requestController.stream;

  /// A stream of processed [Response]s, as in after all [Converter]s and
  /// [Interceptor]s have been run.
  Stream<Response> get onResponse => _responseController.stream;

  void _postInfo() {
    devTools?.addClient(
      _clientId,
      ClientInfo(
        clientId: _clientId,
        baseUrl: baseUrl.toString(),
        httpClient: httpClient.toString(),
        converter: converter?.runtimeType.toString(),
        errorConverter: errorConverter?.runtimeType.toString(),
        authenticator: authenticator?.runtimeType.toString(),
        interceptors:
            interceptors.map((i) => i.runtimeType.toString()).toList(),
        services: _services.keys.map((s) => s.toString()).toList(),
      ),
    );
  }

  void _addCall<BodyType>(
      Call call, Request request, Response<BodyType> response) {
    // devTools?.addCall(
    //
    // );
  }
}

///
/// [ChopperClient] mixin for the purposes of creating mocks
/// using a mocking framework such as Mockito or Mocktail.
///
/// ```dart
/// base class MockChopperClient extends Mock with MockChopperClientMixin {}
/// ```
///
@visibleForTesting
base mixin MockChopperClientMixin implements ChopperClient {}

/// A marker and helper class used by `chopper_generator` to generate network
/// call implementations.
///
///```dart
///@ChopperApi(baseUrl: "/todos")
///abstract class TodosListService extends ChopperService {
///
/// // A helper method that helps instantiating your service
/// static TodosListService create([ChopperClient client]) =>
///     _$TodosListService(client);
///}
///```
abstract class ChopperService {
  late ChopperClient client;

  /// Used internally to retrieve the service from [ChopperClient].
  // TODO: use runtimeType
  Type get definitionType;
}
