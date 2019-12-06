#![feature(try_trait)]
#![feature(generators,generator_trait)]

mod parse_result;
mod table;
mod address;
mod interface;
mod service;
mod rule;
mod virtual_;
mod rulegen;

fn main() {
    std::env::set_current_dir("../nodes/tiamat").unwrap();
    println!("{:?}", crate::address::read_addresses().unwrap());
    println!("{:?}", crate::interface::read_interfaces().unwrap());
    println!("{:?}", crate::service::read_services().unwrap());
    println!("{:?}", crate::rule::read_rules().unwrap());
    /*std::env::set_current_dir("../johann").unwrap();
    println!("{:?}", crate::virtual_::read_virtuals().unwrap());*/

    let rule_gen = crate::rulegen::RuleGen {
        all_interfaces: crate::interface::read_interfaces().unwrap(),
        all_addresses:  crate::address::read_addresses().unwrap(),
        all_services:   crate::service::read_services().unwrap(),
    };
    for rule in &crate::rule::read_rules().unwrap() {
        rule_gen.generate(rule);
    }

}
