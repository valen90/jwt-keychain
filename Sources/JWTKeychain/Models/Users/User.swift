import Vapor
import Fluent
import Foundation
import Auth
import Turnstile
import TurnstileCrypto
import JWT
import Sugar
import FluentMySQL
import VaporForms

/// Defines basic user that can be authorized.
public final class User: UserType {
    public typealias Validator = StoreRequest
    
    public var id: Node?
    public var exists: Bool = false

    public var name: String?
    public var email: String
    public var password: String

    public var createdAt: Date?
    public var updatedAt: Date?
    public var deletedAt: Date?
    
    /// Initializes the User with name, email and password (plain)
    ///
    /// - Parameters:
    ///   - validated: an instance of `StoreRequest` that has a name, email and password.
    public required init(validated: StoreRequest) {
        name = validated.name
        email = validated.email
        password = BCrypt.hash(password: validated.password)
        createdAt = Date()
        updatedAt = Date()
    }
    
    /// Initializes the User with name, email and password (plain)
    ///
    /// - Parameters:
    ///   - name: name of the user
    ///   - email: email of the user
    ///   - password: password of the user (plain)
    public init(name: String, email: String, password: String) {
        self.name = name
        self.email = email
        self.password = BCrypt.hash(password: password)
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// Initializes a User from a given Node
    ///
    /// - Parameters:
    ///   - node: Node with user data
    ///   - context: context
    /// - Throws: if not able to retrieve expected data
    public init(node: Node, in context: Context) throws {
        self.id = try node.extract("id")
        self.name = try node.extract("name")
        self.email = try node.extract("email")
        self.password = try node.extract("password")
        
        if let createdAt = node["created_at"]?.string {
            self.createdAt = Date.parse(.dateTime, createdAt)
        }
        
        if let updatedAt = node["updated_at"]?.string {
            self.updatedAt = Date.parse(.dateTime, updatedAt)
        }
        
        if let deletedAt = node["deleted_at"]?.string {
            self.deletedAt = Date.parse(.dateTime, deletedAt)
        }
    }

    /// Initializes a User with EmailPassword credentials only
    ///
    /// - Parameter credentials: the email and password
    init(credentials: EmailPassword) {
        self.email = credentials.email
        self.password = BCrypt.hash(password: credentials.password)
    }
}


// MARK: - Authorization and registration
extension User {

    /// Authenticates the user with the given credentials
    ///
    /// - Parameter credentials: user credentials
    /// - Returns: authenticated User
    /// - Throws: if we can't get the User
    public static func authenticate(credentials: Credentials) throws -> Auth.User {
        var user: User?

        switch credentials {

        case let credentials as EmailPassword:

            if let fetchedUser = try User.query().filter("email", credentials.email).first(){
                let passwordMatches = try? BCrypt.verify(password: credentials.password, matchesHash: fetchedUser.password)

                if passwordMatches == true {
                    user = fetchedUser
                }
            }

        case let credentials as Identifier:

            user = try User.find(credentials.id)

        case let credentials as Auth.AccessToken:

            let token = try JWT(token: credentials.string)

            if let userId =  token.payload["user"]?.object?["id"]?.int {
                user = try User.query().filter("id", userId).first()
            }

        default:
            throw UnsupportedCredentialsError()
        }

        if let user = user {

            return user

        } else {
            throw IncorrectCredentialsError()
        }
    }

    public static func register(credentials: Credentials) throws -> Auth.User {

        var newUser: User

        switch credentials {
        case let credentials as EmailPassword:
            newUser = User(credentials: credentials)

        default: throw UnsupportedCredentialsError()
        }

        if try User.query().filter("email", newUser.email).first() == nil {

            try newUser.save()

            return newUser
        } else {
            throw AccountTakenError()
        }
    }
}


// MARK: - Vapor Model
extension User {
    public func makeNode(context: Context) throws -> Node {
        return try Node(node: [
            "id": self.id,
            "name": self.name,
            "email": self.email,
            "password": self.password,
            "created_at": self.createdAt?.to(Date.Format.dateTime),
            "updated_at": self.updatedAt?.to(Date.Format.dateTime),
            "deleted_at": self.deletedAt?.to(Date.Format.dateTime)
        ])
    }
    
    public static func prepare(_ database: Database) throws {
        try database.create("users"){ users in
            users.id()
            users.string("name")
            users.string("email")
            users.string("password")
            users.timestamps()
            users.softDelete()
        }

        try database.index(table: "users", column: "email", name: "users_email_index")
    }

    public static func revert(_ database: Database) throws {
        try database.delete("users")
    }
}
