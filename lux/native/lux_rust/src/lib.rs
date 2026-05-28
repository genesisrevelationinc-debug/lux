use rustler::{Env, Term};

mod component;
mod prism;
mod beam;
mod lifecycle;
mod runtime;
mod utils;

use prism::prism_module;
use beam::beam_module;
use runtime::runtime_module;

fn load(env: Env, _info: Term) -> bool {
    runtime::init_runtime();
    env.send_and_clear(&env.pid(), |env| {
        let _ = env;
    });
    true
}

rustler::init!(
    "lux_rust",
    [
        prism_module::run_prism,
        prism_module::validate_prism,
        beam_module::run_beam,
        beam_module::validate_beam,
        runtime_module::spawn_async,
        runtime_module::await_task,
    ],
    load = load
);