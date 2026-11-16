import Foundation
import PreviewLingoCore

private final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

final class TranslationClient {
    private let delegate = NoRedirects()
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }()

    @discardableResult
    func translate(text: String, configuration: TranslationConfiguration, key: String?, completion: @escaping (Result<String, Error>) -> Void) -> URLSessionDataTask? {
        let request: URLRequest
        do {
            request = try TranslationRequest.make(text: text, configuration: configuration, key: key)
        } catch {
            completion(.failure(error))
            return nil
        }
        let task = session.dataTask(with: request) { data, response, error in
            let result: Result<String, Error>
            do {
                if let error = error { throw error }
                guard let http = response as? HTTPURLResponse else { throw TranslationFailure("API 未返回有效响应。") }
                result = .success(try TranslationRequest.parse(data: data ?? Data(), statusCode: http.statusCode, api: configuration.api))
            } catch {
                let message = error.localizedDescription
                let redacted = (key?.isEmpty == false) ? message.replacingOccurrences(of: key!, with: "[redacted]") : message
                result = .failure(TranslationFailure(redacted))
            }
            DispatchQueue.main.async { completion(result) }
        }
        task.resume()
        return task
    }
}
