module solution::pow_solution {
    use sui::tx_context;
    use challenge::pow;

    public entry fun solve(status: &mut pow::Challenge) {
        let id = sui::object::id_bytes(status);
        let proof = pow::prepare_proof(id);
        pow::resolve_proof(status, proof);
    }
}

