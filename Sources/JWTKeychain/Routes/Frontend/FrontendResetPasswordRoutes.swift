import Vapor
import Auth
import Routing
import HTTP

/// Defines basic reset password routes.
public struct FrontendResetPasswordRoutes: RouteCollection {
    public typealias Wrapped = Responder
    
    private let drop: Droplet
    private let configuration: ConfigurationType!
    private let controller: FrontendResetPasswordControllerType!
    
    /// Initializes the user route collection.
    ///
    /// - Parameters:
    ///   - drop: the droplet reference.
    ///   - configuration: configuration for JWT.
    ///     Defaults to `Configuration`.
    ///   - resetPasswordController: controller for handling user reset password
    ///     routes.
    ///     Defaults to `FrontendResetPasswordControllerType`.
    /// - Throws: if configuration cannot be created.
    public init(
        drop: Droplet,
        configuration: ConfigurationType? = nil,
        resetPasswordController: FrontendResetPasswordControllerType? = nil
        ) throws {
        
        self.drop = drop
        let config = try configuration ?? Configuration(drop: drop)
        self.configuration = config
        self.controller = resetPasswordController ?? FrontendResetPasswordController(drop: drop, configuration: config)
        
    }
    
    public func build<Builder: RouteBuilder>(
        _ builder: Builder
        ) where Builder.Value == Responder {
        
        // Get the base path group
        builder.group("reset-password") { routes in
            routes.get("form", String.self, handler: controller.resetPasswordForm)
            routes.post("change", handler: controller.resetPasswordChange)
        }
        
    }
}
