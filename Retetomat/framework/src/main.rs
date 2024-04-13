use std::env;
use std::error::Error;
use std::fmt;
use std::io::{Read, Write};
use std::mem::drop;
use std::net::{TcpListener, TcpStream};
use std::path::Path;
use std::str::FromStr;

use tokio;

use move_transactional_test_runner::framework::{MaybeNamedCompiledModule};
use move_bytecode_source_map::{source_map::SourceMap, utils::source_map_from_file};
use move_binary_format::file_format::CompiledModule;
use move_symbol_pool::Symbol;
use move_core_types::{
    ident_str, 
    account_address::AccountAddress, 
    language_storage::{TypeTag, StructTag}};

use sui_types::Identifier;
use sui_ctf_framework::NumericalAddress;
use sui_transactional_test_runner::{args::SuiValue, test_adapter::FakeID};

async fn handle_client(mut stream: TcpStream) -> Result<(), Box<dyn Error>> {
    
    // Initialize SuiTestAdapter
    let modules = vec!["version4"];
    let sources = vec!["version4"];
    let mut deployed_modules: Vec<AccountAddress> = Vec::new();

    let named_addresses = vec![
        (
            "retetomat".to_string(),
            NumericalAddress::parse_str(
                "0x0", 
            )?,
        ),
        (
            "solution".to_string(),
            NumericalAddress::parse_str(
                "0x0",
            )?,
        ),
    ];

    let precompiled = sui_ctf_framework::get_precompiled(Path::new(&format!(
        "./chall/build/retetomat/sources/dependencies",
    )));

    let mut adapter = sui_ctf_framework::initialize(
        named_addresses,
        &precompiled,
        Some(vec!["challenger".to_string(), "solver".to_string()]),
    ).await;

    let mut mncp_modules : Vec<MaybeNamedCompiledModule> = Vec::new();

    for i in 0..modules.len() {

        let module = &modules[i];
        let _source = &sources[i];

        let mod_path = format!("./chall/build/retetomat/bytecode_modules/{}.mv", module);
        let src_path = format!("./chall/build/retetomat/source_maps/{}.mvsm", module);
        let mod_bytes: Vec<u8> = std::fs::read(mod_path)?;

        let module : CompiledModule = CompiledModule::deserialize_with_defaults(&mod_bytes).unwrap();
        let named_addr_opt: Option<Symbol> = Some(Symbol::from("challenge"));
        let source_map : Option<SourceMap> = Some(source_map_from_file(Path::new(&src_path)).unwrap());
        
        let maybe_ncm = MaybeNamedCompiledModule {
            named_address: named_addr_opt,
            module: module,
            source_map: source_map,
        };
        
        mncp_modules.push( maybe_ncm );
          
    }

    // Publish Challenge Module
    let mut chall_dependencies: Vec<String> = Vec::new();
    let chall_addr = sui_ctf_framework::publish_compiled_module(
        &mut adapter,
        mncp_modules,
        chall_dependencies,
        Some(String::from("challenger")),
    ).await;
    deployed_modules.push(chall_addr);
    println!("[SERVER] Module published at: {:?}", chall_addr); 

    let mut solution_data = [0 as u8; 2000];
    let _solution_size = stream.read(&mut solution_data)?;

    // Send Challenge Address
    let mut output = String::new();
    fmt::write(
        &mut output,
        format_args!(
            "[SERVER] Challenge modules published at: {}",
            chall_addr.to_string().as_str(),
        ),
    )
    .unwrap();
    stream.write(output.as_bytes()).unwrap();

    // Publish Solution Module
    let mut sol_dependencies: Vec<String> = Vec::new();
    sol_dependencies.push(String::from("challenge"));

    let mut mncp_solution : Vec<MaybeNamedCompiledModule> = Vec::new();
    let module : CompiledModule = CompiledModule::deserialize_with_defaults(&solution_data.to_vec()).unwrap();
    let named_addr_opt: Option<Symbol> = Some(Symbol::from("solution"));
    let source_map : Option<SourceMap> = None;
    
    let maybe_ncm = MaybeNamedCompiledModule {
        named_address: named_addr_opt,
        module: module,
        source_map: source_map,
    }; 
    mncp_solution.push( maybe_ncm );

    let sol_addr = sui_ctf_framework::publish_compiled_module(
        &mut adapter,
        mncp_solution,
        sol_dependencies,
        Some(String::from("solver")),
    ).await;
    println!("[SERVER] Solution published at: {:?}", sol_addr);

    // Send Solution Address
    output = String::new();
    fmt::write(
        &mut output,
        format_args!(
            "[SERVER] Solution published at {}",
            sol_addr.to_string().as_str()
        ),
    )
    .unwrap();
    stream.write(output.as_bytes()).unwrap();

    // Prepare Function Call Arguments
    let mut args_sol: Vec<SuiValue> = Vec::new();
    let arg_ob1 = SuiValue::Object(FakeID::Enumerated(1, 0), None);
    args_sol.push(arg_ob1);

    let mut type_args_sol : Vec<TypeTag> = Vec::new();

    // Call solve Function
    let ret_val = sui_ctf_framework::call_function(
        &mut adapter,
        sol_addr,
        "versionC",
        "solve",
        args_sol,
        type_args_sol,
        Some("solver".to_string()),
    ).await;
    println!("[SERVER] Return value {:#?}", ret_val);
    println!("");

    // Check Admin Account
    sui_ctf_framework::view_object(&mut adapter, FakeID::Enumerated(3, 0)).await;

    // Check Solution
    let mut args2: Vec<SuiValue> = Vec::new();
    let arg_ob2 = SuiValue::Object(FakeID::Enumerated(3, 0), None);
    args2.push(arg_ob2);

    let mut type_args_valid : Vec<TypeTag> = Vec::new();

    let sol_ret = sui_ctf_framework::call_function(
        &mut adapter,
        chall_addr,
        "version4",
        "is_expensive",
        args2,
        type_args_valid,
        Some("solver".to_string()),
    ).await;
    println!("[SERVER] Return value {:#?}", sol_ret);
    println!("");

    // Validate Solution
    match sol_ret {
        Ok(()) => {
            println!("[SERVER] Correct Solution!");
            println!("");
            if let Ok(flag) = env::var("FLAG") {
                let message = format!("[SERVER] Congrats, flag: {}", flag);
                stream.write(message.as_bytes()).unwrap();
            } else {
                stream.write("[SERVER] Flag not found, please contact admin".as_bytes()).unwrap();
            }
        }
        Err(_error) => {
            println!("[SERVER] Invalid Solution!");
            println!("");
            stream.write("[SERVER] Invalid Solution!".as_bytes()).unwrap();
        }
    };

    Ok(())
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Create Socket - Port 31338
    let listener = TcpListener::bind("0.0.0.0:31338")?;
    println!("[SERVER] Starting server at port 31338!");

    let local = tokio::task::LocalSet::new();

    // Wait For Incoming Solution
    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                println!("[SERVER] New connection: {}", stream.peer_addr()?);
                    let result = local.run_until( async move {
                        tokio::task::spawn_local( async {
                            handle_client(stream).await.unwrap();
                        }).await.unwrap();
                    }).await;
                    println!("[SERVER] Result: {:?}", result);
            }
            Err(e) => {
                println!("[SERVER] Error: {}", e);
            }
        }
    }

    // Close Socket Server
    drop(listener);
    Ok(())
}
