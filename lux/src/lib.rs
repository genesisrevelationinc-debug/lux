//! # Lux Framework - Rust Component Support
//!
//! This module provides the core functionality for defining and managing
//! Lux components (Prisms and Beams) in Rust with full framework integration.
//!
//! ## Features
//! - Rust component definition system
//! - Trait system integration for components
//! - Async/await support for component execution
//! - Performance optimized component execution
//! - Component lifecycle management

/// Core Lux component types
pub mod component {
    pub use crate::component::LuxComponent;
    pub use crate::component::Prism;
    pub use crate::component::Beam;
    pub use crate::component::Component;
}

pub mod component;
pub mod async_runtime;

/// Example usage:
/// 