import Foundation

final class BackendProcessManager {
	static let shared = BackendProcessManager()

	private enum LaunchMode: String {
		case real
		case mock
	}

	private enum PythonRuntime {
		case direct(URL)
		case env
	}

	private struct LocalEndpoint {
		let scheme: String
		let host: String
		let port: Int

		var healthURL: URL? {
			URL(string: "\(scheme)://\(host):\(port)/health")
		}
	}

	private let queue = DispatchQueue(label: "com.mochi.backend.process")
	private var process: Process?
	private var logHandle: FileHandle?
	private var isLaunching = false

	private init() {}

	func bootstrapIfNeeded() {
		queue.async { [weak self] in
			self?.startIfNeeded()
		}
	}

	func shutdown() {
		queue.async { [weak self] in
			guard let self else { return }
			if let process = self.process, process.isRunning {
				process.terminate()
			}
			self.process = nil
			try? self.logHandle?.close()
			self.logHandle = nil
		}
	}

	private func startIfNeeded() {
		guard !isRunningUnderXCTest else { return }
		guard process?.isRunning != true else { return }
		guard !isLaunching else { return }
		guard let endpoint = localEndpoint() else { return }
		if isBackendHealthy(endpoint: endpoint, timeout: 0.8) {
			return
		}

		guard let backendDirectory = resolveBackendDirectory() else {
			return
		}
		guard let pythonRuntime = resolvePythonRuntime(in: backendDirectory) else {
			return
		}

		isLaunching = true
		defer { isLaunching = false }

		let preferredMode: LaunchMode = hasComposioConfiguration(in: backendDirectory) ? .real : .mock
		if launchBackend(
			mode: preferredMode,
			endpoint: endpoint,
			backendDirectory: backendDirectory,
			pythonRuntime: pythonRuntime
		) {
			if waitForBackend(endpoint: endpoint) {
				return
			}
			log("Backend launch timed out in \(preferredMode.rawValue) mode.")
		}

		guard preferredMode == .real else { return }
		if launchBackend(
			mode: .mock,
			endpoint: endpoint,
			backendDirectory: backendDirectory,
			pythonRuntime: pythonRuntime
		) {
			_ = waitForBackend(endpoint: endpoint)
		}
	}

	private func launchBackend(
		mode: LaunchMode,
		endpoint: LocalEndpoint,
		backendDirectory: URL,
		pythonRuntime: PythonRuntime
	) -> Bool {
		if let process = process, process.isRunning {
			process.terminate()
		}
		process = nil
		try? logHandle?.close()
		logHandle = openLogHandle()

		let process = Process()
		process.currentDirectoryURL = backendDirectory

		let module = mode == .real ? "main:app" : "mock_main:app"
		let arguments = [
			"-m", "uvicorn", module,
			"--host", endpoint.host,
			"--port", String(endpoint.port),
		]

		switch pythonRuntime {
		case .direct(let url):
			process.executableURL = url
			process.arguments = arguments
		case .env:
			process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
			process.arguments = ["python3"] + arguments
		}

		var environment = ProcessInfo.processInfo.environment
		let cacheDirectory = composioCacheDirectory()
		try? FileManager.default.createDirectory(
			at: cacheDirectory,
			withIntermediateDirectories: true
		)
		environment["COMPOSIO_CACHE_DIR"] = cacheDirectory.path
		environment["PYTHONUNBUFFERED"] = "1"
		process.environment = environment

		if let handle = logHandle {
			process.standardOutput = handle
			process.standardError = handle
		}

		process.terminationHandler = { [weak self] terminated in
			self?.queue.async {
				self?.log("Backend exited with status \(terminated.terminationStatus).")
				if self?.process === terminated {
					self?.process = nil
				}
			}
		}

		do {
			try process.run()
			self.process = process
			log("Launched backend in \(mode.rawValue) mode.")
			return true
		} catch {
			log("Failed to launch backend (\(mode.rawValue)): \(error.localizedDescription)")
			return false
		}
	}

	private func waitForBackend(endpoint: LocalEndpoint) -> Bool {
		for _ in 0..<20 {
			if isBackendHealthy(endpoint: endpoint, timeout: 0.8) {
				log("Backend health check succeeded.")
				return true
			}
			Thread.sleep(forTimeInterval: 0.35)
		}
		return false
	}

	private func isBackendHealthy(endpoint: LocalEndpoint, timeout: TimeInterval) -> Bool {
		guard let url = endpoint.healthURL else { return false }
		var request = URLRequest(url: url)
		request.timeoutInterval = timeout

		let semaphore = DispatchSemaphore(value: 0)
		var healthy = false

		let task = URLSession.shared.dataTask(with: request) { _, response, error in
			defer { semaphore.signal() }
			guard error == nil, let http = response as? HTTPURLResponse else { return }
			healthy = (200...299).contains(http.statusCode)
		}
		task.resume()
		_ = semaphore.wait(timeout: .now() + timeout + 0.25)

		return healthy
	}

	private func localEndpoint() -> LocalEndpoint? {
		guard let components = URLComponents(string: BackendConfig.baseURL),
			  let host = components.host?.lowercased() else {
			return nil
		}
		guard host == "127.0.0.1" || host == "localhost" else {
			return nil
		}
		let scheme = components.scheme ?? "http"
		let port = components.port ?? 8000
		return LocalEndpoint(scheme: scheme, host: host, port: port)
	}

	private func resolveBackendDirectory() -> URL? {
		let candidates: [URL] = [
			URL(fileURLWithPath: ProcessInfo.processInfo.environment["MOCHI_BACKEND_PATH"] ?? ""),
			Bundle.main.resourceURL?.appendingPathComponent("backend", isDirectory: true),
			URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("backend", isDirectory: true),
		].compactMap { $0 }

		for candidate in candidates {
			let mainFile = candidate.appendingPathComponent("main.py")
			if FileManager.default.fileExists(atPath: mainFile.path) {
				return candidate
			}
		}

		return nil
	}

	private func resolvePythonRuntime(in backendDirectory: URL) -> PythonRuntime? {
		let bundledPython = backendDirectory.appendingPathComponent(".venv/bin/python")
		if FileManager.default.isExecutableFile(atPath: bundledPython.path) {
			return .direct(bundledPython)
		}

		let systemPython = URL(fileURLWithPath: "/usr/bin/python3")
		if FileManager.default.isExecutableFile(atPath: systemPython.path) {
			return .direct(systemPython)
		}

		let envPath = URL(fileURLWithPath: "/usr/bin/env")
		if FileManager.default.isExecutableFile(atPath: envPath.path) {
			return .env
		}

		return nil
	}

	private func hasComposioConfiguration(in backendDirectory: URL) -> Bool {
		if let envKey = ProcessInfo.processInfo.environment["COMPOSIO_API_KEY"]?
			.trimmingCharacters(in: .whitespacesAndNewlines),
		   !envKey.isEmpty {
			return true
		}

		let dotenvURL = backendDirectory.appendingPathComponent(".env")
		guard let contents = try? String(contentsOf: dotenvURL, encoding: .utf8) else {
			return false
		}

		for rawLine in contents.split(whereSeparator: \.isNewline) {
			let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
			if line.isEmpty || line.hasPrefix("#") { continue }
			guard let separatorIndex = line.firstIndex(of: "=") else { continue }

			let key = String(line[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
			if key != "COMPOSIO_API_KEY" { continue }

			let valueStart = line.index(after: separatorIndex)
			let value = String(line[valueStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
			if !value.isEmpty {
				return true
			}
		}

		return false
	}

	private func applicationSupportDirectory() -> URL {
		let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
			?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
		let directory = base.appendingPathComponent("mochi", isDirectory: true)
		try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		return directory
	}

	private func composioCacheDirectory() -> URL {
		applicationSupportDirectory().appendingPathComponent("composio-cache", isDirectory: true)
	}

	private func openLogHandle() -> FileHandle? {
		let logsDirectory = applicationSupportDirectory().appendingPathComponent("logs", isDirectory: true)
		try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
		let logURL = logsDirectory.appendingPathComponent("backend.log")

		if !FileManager.default.fileExists(atPath: logURL.path) {
			FileManager.default.createFile(atPath: logURL.path, contents: nil)
		}

		guard let handle = try? FileHandle(forWritingTo: logURL) else { return nil }
		_ = try? handle.seekToEnd()
		return handle
	}

	private var isRunningUnderXCTest: Bool {
		let environment = ProcessInfo.processInfo.environment
		return environment["XCTestConfigurationFilePath"] != nil
			|| environment["XCTestSessionIdentifier"] != nil
	}

	private func log(_ message: String) {
		let formatted = "[BackendProcessManager] \(message)\n"
		if let data = formatted.data(using: .utf8) {
			logHandle?.write(data)
		}
		print(formatted.trimmingCharacters(in: .newlines))
	}
}
