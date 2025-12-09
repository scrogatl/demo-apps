use actix_web::{web, App, HttpResponse, HttpServer, Responder};
use serde::{Deserialize, Serialize};
use std::env;

#[derive(Debug, Serialize, Deserialize)]
struct User {
    id: i32,
    name: String,
    email: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct Order {
    id: i32,
    user_id: i32,
    product: String,
    amount: f64,
}

#[derive(Debug, Serialize, Deserialize)]
struct CreateOrderRequest {
    user_id: i32,
    product: String,
    amount: f64,
}

async fn health_check() -> impl Responder {
    HttpResponse::Ok().json(serde_json::json!({
        "status": "healthy",
        "service": "api-gateway"
    }))
}

async fn get_users() -> impl Responder {
    let user_service_url = env::var("USER_SERVICE_URL")
        .unwrap_or_else(|_| "http://user-service:3001".to_string());

    log::info!("Fetching users from {}/users", user_service_url);

    match reqwest::get(format!("{}/users", user_service_url)).await {
        Ok(response) => {
            match response.json::<Vec<User>>().await {
                Ok(users) => {
                    log::info!("Successfully fetched {} users", users.len());
                    HttpResponse::Ok().json(users)
                }
                Err(e) => {
                    log::error!("Failed to parse users: {}", e);
                    HttpResponse::InternalServerError().json(serde_json::json!({
                        "error": format!("Failed to parse response: {}", e)
                    }))
                }
            }
        }
        Err(e) => {
            log::error!("Failed to connect to user service: {}", e);
            HttpResponse::ServiceUnavailable().json(serde_json::json!({
                "error": format!("User service unavailable: {}", e)
            }))
        }
    }
}

async fn get_user(user_id: web::Path<i32>) -> impl Responder {
    let user_service_url = env::var("USER_SERVICE_URL")
        .unwrap_or_else(|_| "http://user-service:3001".to_string());

    log::info!("Fetching user {} from {}/users/{}", user_id, user_service_url, user_id);

    match reqwest::get(format!("{}/users/{}", user_service_url, user_id)).await {
        Ok(response) => {
            if response.status().is_success() {
                match response.json::<User>().await {
                    Ok(user) => HttpResponse::Ok().json(user),
                    Err(e) => HttpResponse::InternalServerError().json(serde_json::json!({
                        "error": format!("Failed to parse response: {}", e)
                    }))
                }
            } else {
                HttpResponse::NotFound().json(serde_json::json!({
                    "error": "User not found"
                }))
            }
        }
        Err(e) => {
            log::error!("Failed to connect to user service: {}", e);
            HttpResponse::ServiceUnavailable().json(serde_json::json!({
                "error": format!("User service unavailable: {}", e)
            }))
        }
    }
}

async fn create_order(order_req: web::Json<CreateOrderRequest>) -> impl Responder {
    let order_service_url = env::var("ORDER_SERVICE_URL")
        .unwrap_or_else(|_| "http://order-service:3002".to_string());

    log::info!("Creating order for user {} via {}/orders", order_req.user_id, order_service_url);

    let client = reqwest::Client::new();
    match client
        .post(format!("{}/orders", order_service_url))
        .json(&order_req.into_inner())
        .send()
        .await
    {
        Ok(response) => {
            if response.status().is_success() {
                match response.json::<Order>().await {
                    Ok(order) => {
                        log::info!("Successfully created order {}", order.id);
                        HttpResponse::Created().json(order)
                    }
                    Err(e) => HttpResponse::InternalServerError().json(serde_json::json!({
                        "error": format!("Failed to parse response: {}", e)
                    }))
                }
            } else {
                let status = response.status();
                let actix_status = actix_web::http::StatusCode::from_u16(status.as_u16())
                    .unwrap_or(actix_web::http::StatusCode::INTERNAL_SERVER_ERROR);
                HttpResponse::build(actix_status).json(serde_json::json!({
                    "error": "Failed to create order"
                }))
            }
        }
        Err(e) => {
            log::error!("Failed to connect to order service: {}", e);
            HttpResponse::ServiceUnavailable().json(serde_json::json!({
                "error": format!("Order service unavailable: {}", e)
            }))
        }
    }
}

async fn get_orders() -> impl Responder {
    let order_service_url = env::var("ORDER_SERVICE_URL")
        .unwrap_or_else(|_| "http://order-service:3002".to_string());

    log::info!("Fetching orders from {}/orders", order_service_url);

    match reqwest::get(format!("{}/orders", order_service_url)).await {
        Ok(response) => {
            match response.json::<Vec<Order>>().await {
                Ok(orders) => {
                    log::info!("Successfully fetched {} orders", orders.len());
                    HttpResponse::Ok().json(orders)
                }
                Err(e) => HttpResponse::InternalServerError().json(serde_json::json!({
                    "error": format!("Failed to parse response: {}", e)
                }))
            }
        }
        Err(e) => {
            log::error!("Failed to connect to order service: {}", e);
            HttpResponse::ServiceUnavailable().json(serde_json::json!({
                "error": format!("Order service unavailable: {}", e)
            }))
        }
    }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    env_logger::init_from_env(env_logger::Env::new().default_filter_or("info"));

    let port = env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    let bind_address = format!("0.0.0.0:{}", port);

    log::info!("Starting API Gateway on {}", bind_address);

    HttpServer::new(|| {
        App::new()
            .route("/health", web::get().to(health_check))
            .route("/users", web::get().to(get_users))
            .route("/users/{id}", web::get().to(get_user))
            .route("/orders", web::get().to(get_orders))
            .route("/orders", web::post().to(create_order))
    })
    .bind(&bind_address)?
    .run()
    .await
}
