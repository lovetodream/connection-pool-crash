import Foundation
@_spi(ConnectionPool) import PostgresNIO

func env(_ key: String) -> String? {
    ProcessInfo.processInfo.environment[key]
}

var config = PostgresClient.Configuration(
    host: env("DATABASE_HOST") ?? "localhost",
    port: env("DATABASE_PORT").flatMap(Int.init(_:)) ?? 5432,
    username: env("DATABASE_USERNAME") ?? "vapor_username",
    password: env("DATABASE_PASSWORD") ?? "vapor_password",
    database: env("DATABASE_NAME") ?? "vapor_database",
    tls: .prefer(.clientDefault)
)
config.options.connectionIdleTimeout = .seconds(20)
config.options.keepAliveBehavior?.frequency = .milliseconds(10 * 1_000 - 5) // a bit of weirdness to produce the crash more often :)

var logger = Logger(label: "connection-pool-crash")
logger.logLevel = .debug

let client = PostgresClient(
    configuration: config,
    backgroundLogger: logger
)
let task = Task {
    await client.run()
}

try await Task.sleep(for: .seconds(1)) // sleep a bit to allow the pool to spin up

/// After x successful attempts, the ConnectionPool crashes due to a failed precondition:
/// "All connections that have been created should say goodbye exactly once!"
///
/// I suspect it is due to a race between ping and close.
/// Ping happens every 10s and close happens after being idle for 20s.
///
/// If connection is created and request happens, the following might occur:
/// 0s (query) -> 10s (ping) -> 20s (close + maybe ping)
for _ in 0..<10 {
    _ = try await client.withConnection { db in
        try await db.query("SELECT 'hello'", logger: logger)
    }.collect().first?.decode(String.self)

    // wait for the connection pool to do ping pong and close
    try await Task.sleep(for: .seconds(22))
}

task.cancel()
