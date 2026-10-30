fn greeting(name: &str) -> String {
    format!("hello from {name} {}", env!("CARGO_PKG_VERSION"))
}

fn main() {
    println!("{}", greeting(env!("CARGO_PKG_NAME")));
}

#[cfg(test)]
mod tests {
    use super::greeting;

    #[test]
    fn greeting_names_the_caller() {
        assert!(greeting("fixture").starts_with("hello from fixture "));
    }
}
