// Test Mock System

#[test_only]
module  legato_vault_addr::mock_validator_tests {

    use std::signer;
    use std::features;

    use legato_vault_addr::mock_validator;
    
    use aptos_framework::reconfiguration;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::coin::{Self}; 
    use aptos_framework::aptos_coin::AptosCoin;

    use aptos_std::stake;

    #[test_only]
    const EPOCH_DURATION: u64 = 86400;

    #[test_only]
    const ONE_APT: u64 = 100000000; // 1x10**8

    #[test_only]
    const LOCKUP_CYCLE_SECONDS: u64 = 3600;

    #[test_only]
    const DELEGATION_POOLS: u64 = 11;

    #[test_only]
    const MODULE_EVENT: u64 = 26;
 
    #[test_only]
    const OPERATOR_BENEFICIARY_CHANGE: u64 = 39;

    #[test_only]
    const COMMISSION_CHANGE_DELEGATION_POOL: u64 = 42;

    #[test_only]
    const COIN_TO_FUNGIBLE_ASSET_MIGRATION: u64 = 60;

    #[test(deployer = @legato_vault_addr, aptos_framework = @aptos_framework, validator_1 = @0x1111, validator_2 = @0x2222, alice = @1234)]
    fun test_mock_system(deployer: &signer, aptos_framework: &signer, validator_1: &signer, validator_2: &signer, alice: &signer) {
        
        initialize_for_test(aptos_framework);

        mock_validator::init_module_for_testing(deployer);
    
        // Prepare test accounts
        create_test_accounts( deployer, validator_1, validator_2, alice);

        // Set commission fees: 10% for validator_1 and 4% for validator_2
        mock_validator::new_pool( signer::address_of(validator_1), 10, 100 );
        mock_validator::new_pool( signer::address_of(validator_2), 4, 100 );

        // Mint APT tokens for validators and alice
        stake::mint(validator_1, 100 * ONE_APT);
        stake::mint(validator_2, 200 * ONE_APT); 
        stake::mint(alice, 30 * ONE_APT); 

        // Stake APT tokens to validators
        mock_validator::stake( validator_1, signer::address_of(validator_1), 100 * ONE_APT);
        mock_validator::stake( validator_2, signer::address_of(validator_2), 200 * ONE_APT); 
        mock_validator::stake( alice, signer::address_of(validator_1), 10 * ONE_APT);
        mock_validator::stake( alice, signer::address_of(validator_2), 20 * ONE_APT);

        // Fast forward time by 100 days
        let i:u64=1;  
        while(i <= 100) 
        {
            timestamp::fast_forward_seconds(EPOCH_DURATION);
            end_epoch();
            i=i+1; // Incrementing the counter
        };

        // Top up rewards for both validators
        stake::mint(deployer, 100 * ONE_APT);
        mock_validator::topup_rewards( deployer, signer::address_of(validator_1) );
        mock_validator::topup_rewards( deployer, signer::address_of(validator_2) );

        // Check staked amounts for alice
        assert!(mock_validator::get_staked( signer::address_of(validator_1), signer::address_of(alice)  )  ==  10_19363766, 0);
        assert!(mock_validator::get_staked( signer::address_of(validator_2), signer::address_of(alice)  ) == 20_38727532 , 1);

        // Unstake APT tokens for alice
        mock_validator::unstake( alice, signer::address_of(validator_1), 10_19363766);
        mock_validator::unstake( alice, signer::address_of(validator_2), 20_38727532);
 
        // Verify alice's final balance
        assert!( coin::balance<AptosCoin>(signer::address_of(alice)) == 3058091298 , 2);
    }

    #[test_only]
    public fun create_test_accounts(
        deployer: &signer,
        validator_1: &signer,
        validator_2: &signer,
        alice: &signer
    ) {
        account::create_account_for_test(signer::address_of(deployer)); 
        account::create_account_for_test(signer::address_of(validator_1));
        account::create_account_for_test(signer::address_of(validator_2)); 
        account::create_account_for_test(signer::address_of(alice)); 
        account::create_account_for_test( mock_validator::get_config_object_address() ); 
    }

    #[test_only]
    public fun initialize_for_test( aptos_framework: &signer) {
        initialize_for_test_custom(
            aptos_framework,
            100 * ONE_APT,
            10000 * ONE_APT,
            LOCKUP_CYCLE_SECONDS,
            true,
            1,
            1000,
            1000000
        );
    }

    #[test_only]
    public fun end_epoch() {
        stake::end_epoch();
        reconfiguration::reconfigure_for_test_custom();
    }

    // Convenient function for setting up the mock system
    #[test_only]
    public fun initialize_for_test_custom(
        aptos_framework: &signer,
        minimum_stake: u64,
        maximum_stake: u64,
        recurring_lockup_secs: u64,
        allow_validator_set_change: bool,
        rewards_rate_numerator: u64,
        rewards_rate_denominator: u64,
        voting_power_increase_limit: u64
    ) {
        account::create_account_for_test(signer::address_of(aptos_framework));
        
        features::change_feature_flags_for_testing(aptos_framework, vector[
            COIN_TO_FUNGIBLE_ASSET_MIGRATION,
            DELEGATION_POOLS,
            MODULE_EVENT,
            OPERATOR_BENEFICIARY_CHANGE,
            COMMISSION_CHANGE_DELEGATION_POOL
        ], vector[ ]);

        reconfiguration::initialize_for_test(aptos_framework);
        stake::initialize_for_test_custom(
            aptos_framework,
            minimum_stake,
            maximum_stake,
            recurring_lockup_secs,
            allow_validator_set_change,
            rewards_rate_numerator,
            rewards_rate_denominator,
            voting_power_increase_limit
        );
    }

}