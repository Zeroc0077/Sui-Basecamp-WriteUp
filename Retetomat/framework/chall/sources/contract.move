module retetomat::version4 {

    use std::string::Self;
    // use std::ascii::Self;
    use std::vector;

    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, ID, UID};
    use sui::url::{Self, Url};
    use sui::transfer;
    use sui::event;

    const E_NotAdmin: u64 = 1337;
    const E_DoctorNotFound : u64 = 1338;
    const E_VMNotFound : u64 = 1339;
    const E_DoctorAlreadyExists : u64 = 1340;
    const E_NotExpensive : u64 = 1342;
    const E_VMAlreadyExists : u64 = 1341;

    #[allow(unused_const)]
    const ADMIN: address = @0x9a219ab86060165c5b290d6218bd42daa86ea85edd9decd81f352412e13647c3;
    #[allow(unused_const)]
    const DOCTOR: address = @0x47fa1f0a1e79172953f36a8ee0f438b31e420768152de742cd41ff74901b7888;
    #[allow(unused_const)]
    const VM: address = @0xA1C05;
    #[allow(unused_const)]
    const PATIENT: address = @0xdeadbeef;


    // ===================================================
    // [*] Resources
    public struct WhiteList has key, store {
        id: UID,
        doc_address: vector<address>,
        vm_address: vector<address>,
    }

    public struct Reteta has key, store {
        id: UID,
        name: string::String,
        description: string::String,
        image_url: Url,
        price: u64,
        date: string::String,
        drugs: vector<string::String>
    }
    
    public struct RetetaMinted has copy, drop {
        reteta_id: ID,
        minted_by: address,
    }

    public struct RetetaBurned has copy, drop {
        items: vector<string::String>,
        burned_by: address,
    }


    // ===================================================
    // [*] Module constructor
    fun init(ctx: &mut TxContext) {

        transfer::share_object(WhiteList {
            id: object::new(ctx),
            doc_address: vector::empty<address>(),
            vm_address: vector::empty<address>()
        })

    }


    // ===================================================
    // [*] Admin functionality to manipulate whitelist 
    //     (add / remove : doctor / vending machine)
    public entry fun add_doc(
        whitelist: &mut WhiteList, 
        doctor_address: address, 
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == ADMIN, E_NotAdmin);
        assert!(!vector::contains(&whitelist.doc_address, &doctor_address), E_DoctorAlreadyExists);
        vector::push_back(&mut whitelist.doc_address, doctor_address);
    }

    public entry fun remove_doc(
        whitelist: &mut WhiteList, 
        doctor_address: address, 
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == ADMIN, E_NotAdmin);
        let (exists, i) = vector::index_of(&whitelist.doc_address, &doctor_address);
        assert!(exists == true, E_DoctorNotFound);
        vector::remove(&mut whitelist.doc_address, i);
    }
   
    public entry fun add_vm(
        whitelist: &mut WhiteList, 
        vending_machine_address: address, 
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == ADMIN, E_NotAdmin);
        assert!(!vector::contains(&whitelist.vm_address, &vending_machine_address), E_VMAlreadyExists);
        vector::push_back(&mut whitelist.vm_address, vending_machine_address);
    }

    public entry fun remove_vm(
        whitelist: &mut WhiteList, 
        vending_machine_address: address, 
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == @retetomat, E_NotAdmin);
        let (exists, i) = vector::index_of(&whitelist.vm_address, &vending_machine_address);
        assert!(exists == true, E_VMNotFound);
        vector::remove(&mut whitelist.vm_address, i);
    }


    // ===================================================
    // [*] Doctor functionality to mint NTFs
    public entry fun mint(
        whitelist: &WhiteList,
        patient: address,
        name: string::String,
        description: string::String,
        price: u64,
        date: string::String,
        drugs: vector<string::String>,
        image_url: string::String,
        ctx: &mut TxContext
    ) {
        let doctor = tx_context::sender(ctx);
        assert!(vector::contains(&whitelist.doc_address, &doctor), E_DoctorNotFound);

        let id = object::new(ctx);
        event::emit(RetetaMinted {
            reteta_id: object::uid_to_inner(&id),
            minted_by: tx_context::sender(ctx),
        });

        let nft = Reteta { 
            id: id, 
            name: name, 
            description: description,
            image_url: url::new_unsafe(string::to_ascii(image_url)) ,
            price: price,
            date: date, 
            drugs: drugs
        };
        transfer::public_transfer(nft, patient);
    }


    // ===================================================
    // [*] Vending Machine functionality to burn NFTs
    public entry fun destroy(
        _whitelist: &mut WhiteList, 
        reteta: Reteta, 
        ctx: &mut TxContext
    ) {
        let burner_addr = tx_context::sender(ctx); 
        // assert!(vector::contains(&whitelist.vm_address, &vm), E_VMNotFound);

        let Reteta { id, name: _, description: _, image_url: _, price: _, date: _, drugs } = reteta;
        object::delete(id);

        event::emit(RetetaBurned {
            items: drugs,
            burned_by: burner_addr, // owner or vending machine
        });
    }


    // ===================================================
    // [*] Patients functionality to inspect NTFs
    public fun get_name(reteta: &Reteta): string::String { reteta.name }

    public fun get_description(reteta: &Reteta): string::String { reteta.description }

    public fun get_items(reteta: &Reteta): &vector<string::String> { &reteta.drugs }

    public fun get_url(reteta: &Reteta): Url { reteta.image_url }

    public fun get_price(reteta: &Reteta): u64 { reteta.price }

    public fun get_doctors(whitelist: &WhiteList): vector<address> { whitelist.doc_address }

    public fun get_vms(whitelist: &WhiteList): vector<address> { whitelist.vm_address }

    public fun is_expensive(reteta: &Reteta) {
        assert!(*string::bytes(vector::borrow(get_items(reteta), 1)) == b"Onasemnogene", E_NotExpensive);
    }

    // ===================================================
    // [*] TESTS

    #[test_only]
    use std::debug;
    #[test_only]
    use sui::test_scenario::{Self, ctx};
    // #[test_only]
    // use sui::coin::{Self, Coin};
    // #[test_only]
    // use sui::sui::SUI;
    #[test_only]
    use sui::random::{Self, Random, new_generator};

    // use retetomat::version1;

    #[test]
    public fun test_admin() {
        // deploy contract
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        // let coin = coin::mint_for_testing<SUI>(100, ctx(scenario));
        init(ctx(scenario));

        // add doctor to whitelist
        test_scenario::next_tx(scenario, ADMIN);

        let mut whitelist = test_scenario::take_shared<WhiteList>(scenario);

        add_doc(&mut whitelist, DOCTOR, ctx(scenario));
        let doctors = get_doctors(&whitelist);
        debug::print(&doctors);

        test_scenario::return_shared(whitelist);
        test_scenario::end(scenario_val);
    }

    #[test_only]
    public fun create_grugs_list() : vector<string::String> {
        let mut drugs : vector<string::String> = vector::empty();
        vector::push_back(&mut drugs, string::utf8(b"Advil"));
        vector::push_back(&mut drugs, string::utf8(b"Strepsils"));
        drugs
    }

    #[test]
    public fun test_doctor() {
        // deploy contract
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        init(ctx(scenario));

        // add doctor to whitelist
        test_scenario::next_tx(scenario, ADMIN);

        let mut whitelist = test_scenario::take_shared<WhiteList>(scenario);
        add_doc(&mut whitelist, DOCTOR, ctx(scenario));
        let doctors = get_doctors(&whitelist);
        debug::print(&doctors);
        test_scenario::return_shared(whitelist);

        test_scenario::next_tx(scenario, DOCTOR);
        whitelist = test_scenario::take_shared<WhiteList>(scenario);
        let patient = PATIENT;
        let name = create_patient_name(ctx(scenario));
        let description = string::utf8(b"For constant pain");
        let price = 12;
        let date = string::utf8(b"10.11.2024");
        let mut drugs : vector<string::String> = create_grugs_list();
        let url = string::utf8(b"https://imgur.com");
        mint(&whitelist, patient, name, description, price, date, drugs, url, ctx(scenario));
        test_scenario::return_shared(whitelist);

        test_scenario::end(scenario_val);
    }

    #[test_only]
    public fun create_patient_name(ctx: &mut TxContext) : string::String {
        let mut name_options : vector<string::String> = vector::empty();
        vector::push_back(&mut name_options, string::utf8(b"Mark"));
        vector::push_back(&mut name_options, string::utf8(b"John"));
        vector::push_back(&mut name_options, string::utf8(b"Alex"));
        vector::push_back(&mut name_options, string::utf8(b"Michael"));
        vector::push_back(&mut name_options, string::utf8(b"David"));

        let r : Random = Random::new();
        let generator = new_generator(r, ctx);
        let index = random::generate_u32_in_range(&mut generator, 0, vector::length(&name_options));
        *vector::borrow(&mut name_options, index)
    }

    #[test]
    public fun test_patient_redeem_drugs() {
        // deploy contract
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        init(ctx(scenario));

        // add doctor to whitelist
        test_scenario::next_tx(scenario, ADMIN);

        let mut whitelist = test_scenario::take_shared<WhiteList>(scenario);
        add_doc(&mut whitelist, DOCTOR, ctx(scenario));
        let doctors = get_doctors(&whitelist);
        debug::print(&doctors);
        test_scenario::return_shared(whitelist);

        test_scenario::next_tx(scenario, DOCTOR);
        whitelist = test_scenario::take_shared<WhiteList>(scenario);
        let patient = PATIENT;
        let name = create_patient_name(ctx(scenario));
        let description = string::utf8(b"For constant pain");
        let price = 12;
        let date = string::utf8(b"10.11.2024");
        let mut drugs : vector<string::String> = create_grugs_list();
        let url = string::utf8(b"https://imgur.com");
        mint(&whitelist, patient, name, description, price, date, drugs, url, ctx(scenario));
        test_scenario::return_shared(whitelist);

        // patient redeems drugs
        test_scenario::next_tx(scenario, PATIENT);

        let reteta = test_scenario::take_from_sender<Reteta>(scenario);
        whitelist = test_scenario::take_shared<WhiteList>(scenario);
        destroy(&mut whitelist, reteta, ctx(scenario));

        test_scenario::return_shared(whitelist);

        test_scenario::end(scenario_val);
    }

    #[test_cnly]
    public fun debug_reteta_creation(
        name: string::String,
        description: string::String,
        price: u64,
        date: string::String,
        drugs: vector<string::String>,
        image_url: string::String,
        ctx: &mut TxContext
    ) {
        let id = object::new(ctx);

        let nft = Reteta { 
            id: id, 
            name: name, 
            description: description,
            image_url: url::new_unsafe(string::to_ascii(image_url)) ,
            price: price,
            date: date, 
            drugs: drugs
        };

        transfer::public_transfer(nft, tx_context::sender(ctx));
    }

    #[test]
    public fun test_multiple_reteta() {
         // deploy contract
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        init(ctx(scenario));

        // add doctor to whitelist
        test_scenario::next_tx(scenario, ADMIN);

        let mut whitelist = test_scenario::take_shared<WhiteList>(scenario);
        add_doc(&mut whitelist, DOCTOR, ctx(scenario));
        let doctors = get_doctors(&whitelist);
        debug::print(&doctors);
        test_scenario::return_shared(whitelist);

        test_scenario::next_tx(scenario, DOCTOR);
        whitelist = test_scenario::take_shared<WhiteList>(scenario);
        let patient = PATIENT;
        let name = create_patient_name(ctx(scenario));
        let description = string::utf8(b"For constant pain");
        let price = 12;
        let date = string::utf8(b"10.11.2024");
        let mut drugs : vector<string::String> = create_grugs_list();
        let url = construct_url(string::utf8(b"https://"), string::utf8(b"www."), string::utf8(b"example."), string::utf8(b"co.uk"), string::utf8(b":80"), string::utf8(b"/blog/article/search"), string::utf8(b"?"), string::utf8(b"docid=720&hl=en"), string::utf8(b"#dayone"));
        mint(&whitelist, patient, name, description, price, date, drugs, url, ctx(scenario));
        test_scenario::return_shared(whitelist);

        // patient redeems drugs
        test_scenario::next_tx(scenario, PATIENT);

        let reteta = test_scenario::take_from_sender<Reteta>(scenario);
        whitelist = test_scenario::take_shared<WhiteList>(scenario);
        destroy(&mut whitelist, reteta, ctx(scenario));

        test_scenario::return_shared(whitelist);

        test_scenario::end(scenario_val);

    }

    #[test_only]
    public fun construct_url(
        scheme: &mut string::String,
        subdomain: string::String,
        domain: string::String,
        top_lvl_domain: string::String,
        port: string::String,
        path: string::String,
        query_separator: string::String,
        query_parameters: string::String,
        fragment: string::String,
        ctx: &mut TxContext
    ) : string::String {
        string::append(scheme, dubdomain);
        string::append(scheme, domain);
        string::append(scheme, top_lvl_domain);
        string::append(scheme, port);
        string::append(scheme, path);
        string::append(scheme, query_separator);
        string::append(scheme, query_parameters);
        string::append(scheme, fragment);
        return scheme
    }

}