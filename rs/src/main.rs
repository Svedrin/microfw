
mod table;
mod address;
mod interface;
mod service;
mod rule;
mod virtual_;


fn main() {
    std::env::set_current_dir("../nodes/tiamat").unwrap();
    println!("{:?}", crate::address::read_addresses().unwrap());
    println!("{:?}", crate::interface::read_interfaces().unwrap());
    println!("{:?}", crate::service::read_services().unwrap());
    println!("{:?}", crate::rule::read_rules().unwrap());
    std::env::set_current_dir("../johann").unwrap();
    println!("{:?}", crate::virtual_::read_virtuals().unwrap());
}
