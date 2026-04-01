Feature: TCS BaNCS Call Center - E2E Security and Trading Flows across Call Center (FO) and BaNCS Core (BO)

  # UI Tests
  @ui @auth @sso @tc-001
  Scenario Outline: SSO login success renders correct role landing without PII exposure
    Given I am on the Call Center login page
    And I select language "<language>"
    When I enter username "<username>" and password "<password>"
    And I click "Login"
    Then I should see the Customer Authentication screen with integrated options
    And I should see the "<landing_tile_1>" and "<landing_tile_2>" tiles on the Trading screen
    And I should not see any PII such as full phone, full email, or PAN
    And the session indicator should show I am logged in as "<role>"

    Examples:
      | language | username    | password    | role       | landing_tile_1     | landing_tile_2   |
      | English  | agent_br01  | ValidPass#1 | BranchAgent| Authorization Queue| E-Journal        |
      | English  | ho_user01   | ValidPass#1 | HO         | Authorization Queue| E-Journal        |

  @ui @auth @security @lockout @mfa @tc-002
  Scenario Outline: Login lockout after failed attempts and MFA step-up on success
    Given I am on the Call Center login page
    When I attempt to login with username "<username>" and wrong password "<wrong_password>" for "<attempts>" times
    Then I should see a generic authentication error without hinting which field failed
    And the account should be locked after "<attempts>" attempts with a generic lockout message
    When I try to login again with the correct password "<password>"
    Then I should see that login is denied due to lockout
    When I use a fresh eligible user "<mfa_user>" and login with correct password "<password>"
    Then I should be challenged for MFA
    When I enter a correct MFA code "<mfa_code>"
    Then I should be logged in successfully to the Customer Authentication screen

    Examples:
      | username   | wrong_password | attempts | password     | mfa_user  | mfa_code |
      | agent_br02 | Wrong#1        | 5        | ValidPass#1  | agent_br03| 123456   |

  @ui @auth @session @tc-003
  Scenario: Session timeout and logout prevent back-button access
    Given I am logged in as a Call Center agent
    And I have navigated to the Trading screen
    When I remain idle for the configured timeout window
    Then my session should expire and I should be redirected to the login page
    When I press the browser back button or access a bookmarked protected URL
    Then I should see the login page again and no protected data should be visible
    When I click "Logout" and then press browser back
    Then I should still see the login page and no new session is created

  @ui @customer-id @masking @tc-004
  Scenario Outline: Customer identification shows masked fields and portfolio selection
    Given I am logged in and on the Customer Authentication screen
    When I select Service Mode "Phone"
    And I choose Identification Type "<id_type>" and enter number "<masked_input>"
    And I click "Authenticate"
    Then I should see a Portfolio List with masked customer details
    And I select portfolio "<portfolio_ref>" and click "Submit"
    Then the customer context should start for "<portfolio_ref>" and I should remain within branch RBAC scope

    Examples:
      | id_type     | masked_input | portfolio_ref |
      | National ID | ******123    | ****7087      |
      | Passport    | ******789    | ****1104      |

  @ui @customer-id @anti-enumeration @tc-005
  Scenario Outline: Invalid identification values return generic errors and throttling
    Given I am on the Customer Authentication screen
    When I enter Identification Type "<id_type>" and invalid Identification Number "<invalid_value>"
    And I click "Authenticate"
    Then I should see a generic error without confirming account existence
    When I rapidly repeat invalid attempts "<repeat_count>" times
    Then I should be throttled or temporarily blocked from further attempts

    Examples:
      | id_type  | invalid_value | repeat_count |
      | Passport | ABC!@#        | 10           |
      | Passport | 00000         | 10           |

  @ui @market-data @entitlements @tc-006
  Scenario Outline: Market data entitlements show live/delayed banners as per subscription
    Given I have customer context for "<customer>"
    When I open Get Quote for "<exchange>" symbol "<symbol>"
    Then I should see "<expected_feed>" banner for quotes and order depth
    When I open "Top Gainers/Losers"
    Then I should see a "Delayed" banner
    When I open "Index Watch"
    Then I should see "Live" data
    When I open "Tax Simulation"
    Then I should see "Delayed" notice

    Examples:
      | customer             | exchange | symbol  | expected_feed |
      | Customer A (foreign live) | TASE    | TASE1   | Live          |
      | Customer A (foreign live) | NASDAQ  | AAPL    | Live          |
      | Customer B (no foreign)   | NASDAQ  | MSFT    | Delayed       |

  @ui @orders @equity @fees @trail @tc-007
  Scenario Outline: Equity Buy order Create -> Preview (alerts) -> Confirm -> Execution trail
    Given I have customer context with sufficient buying power
    And I open Order Entry
    When I select "<exchange>" symbol "<symbol>" and set Quantity "<qty>" and Limit Price "<price>" and TIF "<tif>"
    And I click "Place Order"
    Then I should see pre-order alerts of class "<alert_class>" as configured
    When I review commission and check "I Agree" and click "Confirm"
    Then I should see an Internal Order Number and link to Order Book
    When the order executes
    Then Order Book should show status progression Authorized -> Placed with Market -> Executed
    And Order Trail should list immutable events with timestamps and fees

    Examples:
      | exchange | symbol | qty | price   | tif | alert_class  |
      | TASE     | ABC    | 100 | 101.25  | GFD | Information  |
      | TASE     | ABC    | 100 | 0.10    | GFD | Error        |
      | TASE     | ABC    | 5   | 101.25  | GFD | Warning      |

  @ui @rbac @maker-checker @poa @tc-009
  Scenario: POA trading restriction triggers maker-checker and E-Journal entries
    Given I am logged in as an agent who is a POA on the account
    And maker limits require approval for the order size
    When I attempt to place a Buy order
    Then an Authorization popup should appear to assign a checker
    When I assign an authorizer and submit
    Then the request should move to the checker’s My Queue
    When the checker approves
    Then the order should resume and be placed with the market
    And E-Journal should show entries under "Initiated By Me" and "Authorized By Me"

  @ui @rbac @maker-checker @pool @tc-010
  Scenario: Orders over maker limit route to Pool Queue and require approval
    Given I am logged in as a maker with a low limit
    When I place a large equity order exceeding my maker limit
    Then a maker limit exceeded authorization request should be created
    When any eligible authorizer picks the request from Pool Queue and approves
    Then the order should proceed
    And E-Journal should reflect correct initiator and authorizer

  @ui @orders @modify-cancel @trail @tc-011
  Scenario: Order modification and cancellation are reflected with immutable trails
    Given I have two pending equity orders A and B
    When I modify Order A price and confirm
    Then Order A status should show "Modified" after exchange confirmation
    When I cancel Order B and confirm
    Then Order B status should show "Cancelled" after exchange confirmation
    And both Order Trails should show full chronology including exchange references

  @ui @reports @rbac @masking @auditor @tc-012 @tc-033
  Scenario Outline: Exports masking and RBAC scope for HO/Branch/Auditor roles
    Given I am logged in as "<role>"
    When I open In-job Order Book
    Then the Call Centre selector "<all_option_visibility>" for ALL should behave per role policy
    When I export Order/Trade history
    Then exported data should mask PII (phone +972*****1234, email a***@domain.com, PAN 4111********1111) and exclude CVV
    And I should not be able to place/modify orders or initiate transfers if role is "Auditor"

    Examples:
      | role        | all_option_visibility      |
      | HO          | is available               |
      | BranchAgent | is not available           |
      | Auditor     | is available read-only     |

  @ui @transfers @within-bank @multi-beneficiary @tc-013
  Scenario: Security Transfer within bank with same-entity auto-detect and multi-beneficiary split
    Given I am logged in as a branch agent with MU matching the customer portfolio
    And I open Transfers > Security Transfer
    When I select settled TASE positions and enter fractional quantities
    And I add beneficiary "Within Bank" and choose Transfer Case "Transfer between relatives"
    And I add two beneficiaries with percentages totaling 100%
    Then the system should auto-detect Same Entity via BP ID where applicable and disable Transfer Case for those
    When I preview, print commission, agree and Release
    Then the order should be created with custody blocks and status "Released" and await authorization
    When Checker #1 and then Checker #2 approve
    Then the order should be Authorized and settle by EOD
    And Security Transfer History shows Released -> Authorized -> Settled with audit/E-Journal entries

  @ui @transfers @validation @blocks @tc-016 @tc-017
  Scenario Outline: Transfer entry validation blocks CA ex-date and MU mismatch
    Given I am logged in as "<role>"
    When I open Transfers > Security Transfer on "<security_condition>"
    Then I should see the error "<expected_message>" and no order should be created

    Examples:
      | role        | security_condition        | expected_message                                                     |
      | BranchAgent | security on CA ex-date    | Security Transfer is not allowed for this security                   |
      | BranchAgent | MU mismatch customer/MU   | Kindly visit your home branch to transfer Security                   |

  # API Tests
  @api @orders @self-transaction @tc-008
  Scenario Outline: API blocks TASE self-transaction at BP level
    Given the API base URL is "<base_url>"
    And the authorization token for role "Agent" is set
    And there exists an open Buy order for BP "<bp_id>" on symbol "<symbol>" at price "<open_price>"
    When I send a POST request to "/api/orders" with JSON body
      """
      {
        "bpId": "<bp_id>",
        "portfolioRef": "<portfolio>",
        "exchange": "TASE",
        "symbol": "<symbol>",
        "side": "SELL",
        "orderType": "MKT",
        "quantity": 100
      }
      """
    Then the response status should be 400
    And the response JSON should contain errorCode "SELF_TX_BLOCK" and message "Self-Transactions are not allowed in TASE"
    And no order should be created for this request

    Examples:
      | base_url                    | bp_id    | portfolio | symbol | open_price |
      | https://bancs.example.com   | BP12345  | ****7087  | ABC    | 101.50     |

  @api @transfers @outside-bank @tase-files @recon @tc-015
  Scenario Outline: API Outside Bank transfer generates File 15 and reconciles via 1051/1052
    Given the API base URL is "<base_url>"
    And the authorization token for role "Agent" is set
    When I create an Outside Bank transfer by POST "/api/transfers" with JSON body
      """
      {
        "type": "OUTSIDE_BANK",
        "exchange": "TASE",
        "sourcePortfolio": "<portfolio>",
        "beneficiary": {
          "bankCode": "<bank_code>",
          "branchCode": "<branch_code>",
          "accountNumber": "<account_number>",
          "owners": [
            {"idType":"NationalID","idNumber":"******123","name":"Masked Name"}
          ]
        },
        "lines": [
          {"symbol":"<symbol>","quantity":100.000}
        ]
      }
      """
    Then the response status should be 201
    And the response JSON should contain "status" "Authorized"
    When I trigger next BOD batch by POST "/api/files/tase/15/run"
    Then the response status should be 202
    And I poll GET "/api/transfers/<transferId>" every 300s for up to 1800s until field "reconStatus" is "Reconciled"
    When I upload TASE 1051 by POST "/api/files/tase/1051" with body containing this transfer
    And I upload TASE 1052 by POST "/api/files/tase/1052" for settlement
    Then GET "/api/transfers/<transferId>" should show "status" "Settled" and reconciliation markers present

    Examples:
      | base_url                  | portfolio | bank_code | branch_code | account_number | symbol |
      | https://bancs.example.com | ****7087  | 1245      | 5124        | ********5454   | ABC    |

  @api @transfers @virtual-sell @conflict @tc-018
  Scenario Outline: Virtual Sell capability conflict (FO vs BO)
    Given the API base URL is "<base_url>"
    And the authorization token for role "<role>" is set
    When I send a POST request to "/api/transfers" with JSON body
      """
      {
        "type": "WITHIN_BANK",
        "virtualSell": true,
        "sourcePortfolio": "<portfolio>",
        "beneficiary": {"accountNumber":"<portfolio>"},
        "lines": [{"symbol":"XYZ","quantity":50.000}]
      }
      """
    Then the response status should be <expected_status>
    And the response message should contain "<expected_message>"

    Examples:
      | base_url                  | role   | portfolio | expected_status | expected_message                       |
      | https://bancs.example.com | FO     | ****7087  | 403             | Virtual Sell is supported only from BO |
      | https://bancs.example.com | BO     | ****7087  | 201             | Authorized                             |

  @api @authz @csrf @security @tc-035
  Scenario Outline: Anti-CSRF on approval endpoint blocks forged requests
    Given the API base URL is "<base_url>"
    And no active session cookie and no CSRF token are present
    When I send a POST request to "/api/authorization/approve" with JSON body
      """
      {
        "requestId": "<request_id>",
        "decision": "APPROVE",
        "remarks": "forged"
      }
      """
    Then the response status should be <status>
    And the response should not change approval state

    Examples:
      | base_url                  | request_id | status |
      | https://bancs.example.com | ****0123   | 401    |
      | https://bancs.example.com | ****0123   | 403    |

  @ui @orders @idempotency @tc-034
  Scenario Outline: Duplicate submission defense on Confirm (order and transfer)
    Given I have a prepared "<flow_type>" at the Preview/Release step
    When I rapidly double-click "<confirm_button>"
    Then exactly one "<entity>" should be created and shown in the respective book/history
    And a duplicate warning or same Internal Order Number is returned for the second click

    Examples:
      | flow_type         | confirm_button | entity            |
      | Equity Order Buy  | Confirm        | order             |
      | Security Transfer | Release        | transfer order    |

  @api @trades @1054 @fail-pending @tc-028
  Scenario Outline: File 1054 updates Failed/Pending trade statuses and manual blocks are handled
    Given the API base URL is "<base_url>"
    And the authorization token for role "BO" is set
    And an executed trade exists with Internal Order Number "<order_ref>"
    When I upload TASE 1054 by POST "/api/files/tase/1054" marking the trade "<status>"
    Then the order/trade status should update to "<status>" with reconciliation markers
    And BO instructions are generated to create appropriate manual blocks
    When remediation is completed and settlement advice is matched
    Then status should transition to "Settled" and blocks cleared

    Examples:
      | base_url                  | order_ref | status  |
      | https://bancs.example.com | ****0655  | Failed  |
      | https://bancs.example.com | ****0655  | Pending |

  @ui @orders @types @stoploss @fok @tc-025 @tc-026
  Scenario Outline: Order type field enablement and FOK behavior
    Given I am on Order Entry for symbol "<symbol>"
    When I choose Order Type "<order_type>"
    Then the fields "<trigger_field_state>" for Trigger and "<price_field_state>" for Price should apply
    When I submit the order with Quantity "<qty>" and Limit "<limit>"
    Then the exchange behavior should be "<expected_outcome>"

    Examples:
      | symbol | order_type     | trigger_field_state | price_field_state | qty   | limit  | expected_outcome                      |
      | ABC    | Market         | disabled            | disabled          | 10    |       | Accepted if validations pass          |
      | ABC    | Stoploss       | enabled             | enabled           | 10    | 94    | Accepted if trigger < LTP and limit   |
      | XYZ    | Fill or Kill   | n/a                 | enabled           | 10000 | 10.00 | Cancelled if immediate full not available |
      | XYZ    | Fill or Kill   | n/a                 | enabled           | 5000  | 10.00 | Fully executed immediately            |

  @ui @tax @simulation @delay @tc-020
  Scenario: Tax Simulation always shows delayed data and produces results without state change
    Given I have customer context with holdings
    When I open Tax Simulation and select a security and edit quantity and price
    And I click "Simulate"
    Then I should see a "Delayed" indicator on market data
    And I should see Tax To Pay/Refund per security in ILS and an option to Sell
    And no state change should occur beyond simulation

  @api @incoming-132 @repair @tc-019 @tc-032
  Scenario Outline: Incoming File 132 creates Delivery In and supports To Be Repaired flow
    Given the API base URL is "<base_url>"
    And the authorization token for role "BO" is set
    When I upload a TASE 132 file by POST "/api/files/tase/132" containing "<record_type>" records
    Then the system should create Delivery In orders with status "<expected_status>"
    When I repair mismatched details by PUT "/api/transfers/<transferId>/repair" with JSON body
      """
      {
        "beneficiary": {"accountNumber": "****7087"},
        "owners": [{"idType":"NationalID","idNumber":"******123"}]
      }
      """
    Then the status should update to "Authorized"
    And upon settlement advice match, the status should be "Settled"

    Examples:
      | base_url                  | record_type | expected_status |
      | https://bancs.example.com | valid       | Authorized      |
      | https://bancs.example.com | id_mismatch | To Be Repaired  |
