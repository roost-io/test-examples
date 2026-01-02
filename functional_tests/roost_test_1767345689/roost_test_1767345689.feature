Feature: Security-sensitive E2E Journeys for TCS BaNCS Call Center (FO) and BaNCS Back Office (BO)

  # =========================================
  # E2E DATA FLOW MAP (concise, security-sensitive journeys)
  # =========================================
  # Journey 1: Agent login / MFA / lockout (ASSUMPTION: MFA via OTP)
  # Call Center input -> username/password on SSO screen
  # Request to Backend -> SSO token validation; role fetch; login attempt counter
  # Backend validations -> Account active; failed-attempt threshold; RBAC scope
  # Backend state -> Session created; counters updated; lockout flag on threshold
  # Response -> Login success/failure; masked error
  # Verify -> UI Dashboard; BO audit LOGIN_SUCCESS/FAIL/MFA_CHALLENGE/ACCOUNT_LOCKED
  #
  # Journey 2: Customer identification + verification (ASSUMPTION: optional OTP/KBA)
  # Call Center input -> Service Mode + Identification Type/Number OR Portfolio Ref
  # Request to Backend -> Lookup BP ID/Portfolio; KBA/OTP validation
  # Backend validations -> Anti-enumeration; OTP single-use
  # Backend state -> Customer context bound to session; verification result recorded
  # Response -> Portfolio list with masked refs
  # Verify -> UI list; BO audit CUSTOMER_VERIFY(_SUCCESS/_FAIL)
  #
  # Journey 3: Sensitive profile change (ASSUMPTION – not detailed in docs)
  # Call Center input -> Edit email/phone; step-up auth
  # Request to Backend -> RBAC check; write change; PII masking in logs
  # Backend state -> Contact updated; audit trail written
  # Response -> Success banner w/o full PII
  # Verify -> Audit PROFILE_UPDATE (masked)
  #
  # Journey 4: Equity/ETF/MF order placement
  # Call Center input -> Create -> Preview -> Confirm
  # Request to Backend -> Pre-trade checks; TASE self-transaction rule
  # Backend state -> Authorized -> Placed -> Executed/Partial -> Settled (1051/1052)
  # Response -> Order/Trade book updates; commission preview
  # Verify -> UI books; BO audit ORDER_CREATE/MODIFY/CANCEL/EXECUTE; recon files processed
  #
  # Journey 5: Security Transfer Within/Outside Bank/Virtual Sell
  # Call Center input -> Select Security -> Add Beneficiary -> Preview -> Release -> Authorization
  # Request to Backend -> Validate MU; same-entity; ex-date prohibition; TASE-only for Outside Bank; virtual sell
  # Backend state -> Released -> Authorized (checker) -> Pend Settle/Open Delivery -> Settled
  # Response -> Confirmation; Authorization Queue; Transfer History
  # Verify -> UI history; BO open deliveries; file 15/132 in/out; 1051/1052 match; tax-lot carryover
  #
  # Journey 6: Tax Simulation -> Sell -> Settlement/Tax
  # Call Center input -> Simulate tax -> Sell
  # Request to Backend -> Call tax engine via BO; compute tax; apply on settlement
  # Backend state -> Lots closed; tax postings created
  # Response -> Simulation results; sell confirm
  # Verify -> UI tax preview; BO movements + TAX_POSTING; audits TAX_SIMULATE/SELL_ORDER
  #
  # Journey 7: MF price correction (reverse/reallocate)
  # Call Center input -> MF order placed; later price correction in history
  # Request to Backend -> Auto/Manual reversal & reallocation via 1051/1052
  # Backend state -> Allocation reversed; reallocated; cash/units adjusted
  # Response -> Order Trail shows reversal/reallocation
  # Verify -> Movements; audit PRICE_CORRECTION; fees re-applied properly
  #
  # Journey 8: Reconciliation & Net Settlement
  # Call Center input -> Views for history/status
  # Request to Backend -> Process 1051,1052,1054; 32/1091; 871/872
  # Backend state -> Reconciled/Not Matched/Failed; settlement advice linked
  # Response -> Reports; exceptions list
  # Verify -> Files processed; statuses updated; exception reports generated
  #
  # Journey 9: Call recording access control (ASSUMPTION)
  # Call Center input -> Search/play/export recording (RBAC + audit)
  # Request to Backend -> Authorize; time-bound token; watermark; audit
  # Backend state -> Access log entries
  # Response -> Player opens with masked metadata
  # Verify -> Audit RECORDING_ACCESS; no raw PII in URLs
  #
  # Terminology Mapping (Doc references + ASSUMPTION if not explicit)
  # - Customer BP Identifier (Call Center) = BP ID (Backend) [Doc A: 2.1; Doc B: 4]
  # - Portfolio Reference (Call Center) = Portfolio Id (Backend) [Doc A: 2.1; 12.1–12.5]
  # - Internal Order Number (Call Center) = Order/Deal/Allocation Id (Backend) [Doc A: 3.5/3.6; Doc B: 3.1]
  # - Open Delivery (Backend) = Pend Settle (Call Center) [Doc A: 12.5; Doc B: 3.1/4]
  # - Settlement Advice (Backend) = 1052 confirmation [Doc B: 3.1]
  # - Same Entity (Call Center) = Same Entity Tax Identifier (Backend) [Doc A: 12.2; Doc B: 4]
  # - Authorization Queue/My Queue (Call Center) = Checker workflow (Backend) [Doc A: 12.5, 13]
  # - Previous Closing Price (Call Center) = Security Rates t-1 (Backend) [Doc A: 12.1; Doc B: 1.2.1]
  # - ENTITLEMENT decisions (Call Center display) = MI/ORS entitlement check (Backend) [Doc A: 11]

  Background:
    Given the Call Center UI base URL is 'https://cc.test.bank'  # environment variable CC_BASE_URL
    And the Backend API base URL is 'https://api.test.bank'      # environment variable API_BASE_URL
    And the default API headers include 'Content-Type: application/json'
    And audit/log search is available via secured endpoint  # ASSUMPTION: /api/audit/search
    And file gateways/simulators for TASE 1051/1052/1054/32/1091 and 132 are available  # per prerequisites

  # =========================================
  # UI Tests: Authentication, MFA, Lockout, Masking
  # =========================================
  @ui @auth @mfa
  Scenario Outline: SSO login with MFA and lockout handling with masked errors
    Given I am on the Call Center login page
    When I attempt login as '<userId>' with password '<password>' <attempts> times
    Then I should see '<uiMessage>'
    And I should not see sensitive credentials or OTP details in the UI
    And if login is successful I should land on the Dashboard with masked header widgets

    Examples:
      | userId  | password     | attempts | uiMessage                                  |
      | agent01 | wrongPass    | 5        | Account locked or Invalid credentials      |  # lockout at 5 (ASSUMPTION)
      | agent01 | correctPass! | 1        | MFA challenge sent                         |
      | agent01 | otpWrongThenCorrect | 2 | MFA invalid once then success to Dashboard |

  @api @auth @audit
  Scenario Outline: Audit trail for login, MFA and lockout
    Given the authorization token for audit API is set
    When I send a GET request to '/api/audit/search?userId=<userId>&event=<event>'
    Then the response status should be 200
    And the response JSON should contain 'events' with at least <minCount> record(s)
    And no field should contain raw password or OTP values

    Examples:
      | userId  | event             | minCount |
      | agent01 | LOGIN_FAIL        | 5        |
      | agent01 | ACCOUNT_LOCKED    | 1        |
      | agent01 | MFA_CHALLENGE     | 1        |
      | agent01 | LOGIN_SUCCESS     | 1        |

  # =========================================
  # UI + API Tests: Customer Identification, OTP, Anti-enumeration
  # =========================================
  @ui @verify @pii
  Scenario Outline: Customer identification with OTP and anti-enumeration UX
    Given I am on the Customer Authentication screen
    When I select Service Mode 'Phone' and Identification Type 'National Id' and enter '<maskedId>'
    And I click 'Authenticate'
    Then I should see '<expectedPrompt>'
    And the portfolio list, if shown, must display masked portfolio refs

    Examples:
      | maskedId      | expectedPrompt                              |
      | 0*******664   | OTP challenge if risk policy triggers       |
      | random******* | Generic error without existence hint        |

  @api @verify @rateLimit
  Scenario Outline: Anti-enumeration and rate limiting on identification API
    Given the authorization token for customer API is set
    When I send a POST request to '/api/customers/verify' with payload
      """
      {
        "channel": "PHONE",
        "identType": "NATIONAL_ID",
        "identValue": "<idValue>",
        "otp": "<otp>"
      }
      """
    Then the response status should be <status>
    And the response JSON should contain '<responseField>'
    And error messages must be generic and timing within ±100ms band  # ASSUMPTION timing window

    Examples:
      | idValue       | otp      | status | responseField      |
      | 0123456664    | 123456   | 200    | portfolios         |
      | 9999999999    |          | 429    | rateLimit          |
      | 0123456664    | 000000   | 401    | genericError       |

  # =========================================
  # UI + API Tests: Market Data Entitlements and Masking
  # =========================================
  @ui @entitlement
  Scenario Outline: Enforce live vs delayed market data across widgets and order depth
    Given I am an agent entitled for local live and foreign delayed data
    When I open '<widget>' for '<symbol>' on '<market>'
    Then I should see '<dataMode>' prices with appropriate banner if delayed
    And Order Depth should be '<depthAllowed>'

    Examples:
      | widget       | symbol   | market  | dataMode | depthAllowed |
      | MarketWatch  | TASE_S1  | Local   | Live     | Allowed      |
      | GetQuote     | FXN_S2   | Foreign | Delayed  | Denied       |

  @api @entitlement @negative
  Scenario: Direct REST call to foreign live depth should be blocked
    Given the authorization token for market data API is set
    When I send a GET request to '/api/market/depth?symbol=FXN_S2&exchange=FOREIGN&mode=live'
    Then the response status should be 403
    And the response JSON should contain 'error' with 'forbidden'

  # =========================================
  # UI + API Tests: TASE Self-Transaction Block (BP level)
  # =========================================
  @ui @orders @tase
  Scenario Outline: Block self-crossing orders at BP level per TASE rule
    Given I have authenticated the customer and selected a portfolio under BP '<bpId>'
    And there is an open Sell order at price 100 for symbol 'S' under the same BP
    When I place a '<side>' order with type '<orderType>' and price '<price>' for symbol 'S'
    Then I should see '<uiOutcome>'
    And the UI error message must be 'Self-Transactions are not allowed in TASE' when blocked

    Examples:
      | bpId   | side | orderType | price | uiOutcome                 |
      | BP123  | Buy  | MKT       | -     | Blocked                   |
      | BP123  | Buy  | LIMIT     | 101   | Blocked                   |
      | BP123  | Buy  | LIMIT     | 99    | Allowed to proceed        |

  @api @orders @audit
  Scenario Outline: Audit decision logged for self-transaction checks
    Given the authorization token for order validation API is set
    When I send a GET request to '/api/audit/search?event=SELF_TXN_CHECK&bpId=<bpId>&symbol=S'
    Then the response status should be 200
    And the response JSON should contain 'decision' with '<decision>'

    Examples:
      | bpId  | decision |
      | BP123 | BLOCK    |
      | BP123 | ALLOW    |

  # =========================================
  # UI + API Tests: Maker–Checker approval for equity buy (limit exceeded)
  # =========================================
  @ui @authz @makerChecker
  Scenario: Equity buy exceeds maker limit -> assign to specific checker and approve
    Given I am on Equity Order Entry and I create a Buy order exceeding my maker limit
    When I click 'Place Order' then 'Assign' to specific authorizer 'sup01' with remarks
    Then I should see the request queued and status 'Pending Authorization'
    And as Checker 'sup01' I open 'My Queue' and approve the request
    And the order status should move to 'Authorized/Placed With Market'

  @api @files @recon
  Scenario: Ingest 1051 and 1052 to reconcile and settle authorized order
    Given the authorization token for file ingest API is set
    When I send a POST request to '/api/sim/files/1051/ingest' with payload
      """
      { "orders": [{"orderId":"O-123","symbol":"LPSN.D","execQty":100,"price":10.5}] }
      """
    Then the response status should be 202
    And I send a POST request to '/api/sim/files/1052/ingest' with payload
      """
      { "settlements": [{"orderId":"O-123","cash":"-1050.00","qty":100}] }
      """
    Then the response status should be 202
    And I send a GET request to '/api/orders/O-123/status'
    Then the response status should be 200
    And the response JSON should contain 'reconciliation' with 'Reconciled' and 'settled' true

  # =========================================
  # UI Tests: ETF order path selection security
  # =========================================
  @ui @etf @path
  Scenario Outline: ETF order path chooser enforces entitlements and fees
    Given I open the ETF List and click 'Buy' on '<etfSymbol>'
    When the path chooser modal appears I select '<path>'
    Then the corresponding order entry screen opens with appropriate quote mode
    And commission preview should match the selected path tariff

    Examples:
      | etfSymbol | path        |
      | ETF123    | Equity Path |
      | ETF123    | MF Path     |

  # =========================================
  # UI + API Tests: Mutual Fund redeem with auto price correction (reverse/reallocate)
  # =========================================
  @ui @mf @priceCorrection
  Scenario: MF redeem order then UI shows reversal/reallocation in order trail
    Given I place an MF Redeem order from NAV List and confirm
    When price correction is processed later by BO (simulated)
    Then the MF Order Trail should show reversal and reallocation entries with new NAV

  @api @mf @files
  Scenario: Process MF price correction via 1051/1052
    Given the authorization token for file ingest API is set
    When I send a POST request to '/api/sim/files/1051/ingest' with payload
      """
      {
        "mfCorrections": [{
          "internalOrderId":"MF-789",
          "action":"REVERSE_AND_REALLOCATE",
          "oldNav": 10.0,
          "newNav": 9.8,
          "units": 100
        }]
      }
      """
    Then the response status should be 202
    And I send a POST request to '/api/sim/files/1052/ingest' with payload
      """
      { "mfSettlements": [{"orderId":"MF-789","status":"Settled"}] }
      """
    Then the response status should be 202
    And I send a GET request to '/api/audit/search?event=MF_PRICE_CORRECTION_AUTO&orderId=MF-789'
    Then the response status should be 200

  # =========================================
  # UI + API Tests: Security Transfer Outside Bank with validations and maker–checker
  # =========================================
  @ui @transfer @outsideBank
  Scenario: Outside Bank transfer blocks ex-date and enqueues for authorization
    Given I open Security Transfer -> Add Security and select symbols A (no CA) and B (ex-date today)
    When I proceed with B I should get a hard error for ex-date block
    And I proceed with A, set Transfer Type 'Outside Bank', enter beneficiary bank/branch/account, Same Entity unchecked, Transfer Case 'Transfer between relatives' -> 'Sister/brother'
    And I preview, agree commission and click 'Release'
    Then I should see confirmation with internal transfer reference
    And I initiate Authorization and assign to Pool
    And as Checker I pick from Pool and approve
    Then status should move to 'U–Authorized' and an Open Delivery created

  @api @transfer @files
  Scenario: File 15 enqueue and 1051/1052 settlement for outside bank transfer
    Given the authorization token for file and transfer APIs is set
    When I send a POST request to '/api/transfers/T-456/queueFile15'
    Then the response status should be 202
    And I send a POST request to '/api/sim/files/1051/ingest' with payload
      """
      { "transfers": [{"transferId":"T-456","match":"Y"}] }
      """
    Then the response status should be 202
    And I send a POST request to '/api/sim/files/1052/ingest' with payload
      """
      { "transfers": [{"transferId":"T-456","settled":true}] }
      """
    Then the response status should be 202
    And I send a GET request to '/api/transfers/T-456/status'
    Then the response status should be 200
    And the response JSON should contain 'status' with 'Settled'

  # =========================================
  # UI + API Tests: Within Bank Virtual Sell and tax lots
  # =========================================
  @ui @transfer @virtualSell
  Scenario: Virtual Sell within bank auto-sets target=source and settles EOD
    Given I start Security Transfer and choose 'Within Bank' then tick 'Virtual Sell'
    When I select a security and fractional qty '12.345' and Release with assignment to a specific Checker
    Then Checker approves and status becomes 'Authorized'
    And after EOD the History shows 'Settled' and Same Entity true

  @api @tax
  Scenario: Tax engine update for virtual sell
    Given the authorization token for tax API is set
    When I send a POST request to '/api/tax/updates' with payload
      """
      { "transferId":"VS-001","indicator":"VIRTUAL_SELL","lots":[{"symbol":"SYM","qty":12.345}] }
      """
    Then the response status should be 202

  # =========================================
  # UI + API Tests: PII masking across UI, exports and logs
  # =========================================
  @ui @pii @exports
  Scenario Outline: Verify PII masking in UI and exported reports
    Given I am authenticated and open '<screen>'
    When I export data to '<format>'
    Then the on-screen values and exported file must show masked identifiers only
    And no full National ID or phone or PAN should be visible

    Examples:
      | screen                 | format |
      | Portfolio Valuation    | Excel  |
      | Order History          | CSV    |
      | Trade History          | CSV    |

  @api @pii @audit
  Scenario: Audit/log records are pseudonymous with no raw PII
    Given the authorization token for audit API is set
    When I send a GET request to '/api/audit/search?scope=recent&contains=phone'
    Then the response status should be 200
    And the response JSON should not contain '+972*****1234' or '4111********1111' or 'a***@domain.com'

  # =========================================
  # UI Tests: Session timeout, logout invalidation, and step-up on Release
  # =========================================
  @ui @session @stepUp
  Scenario: Idle timeout and step-up re-auth before Release of sensitive transfer
    Given I am on Security Transfer Preview screen with a pending draft
    When I remain idle for 15 minutes  # ASSUMPTION: idle timeout = 15 min
    Then my session should expire and I am redirected to login on next action
    When I login again and return to the draft and click 'Release'
    Then I should be prompted for step-up authentication and upon success the Release proceeds
    And after logout, reusing old URL should redirect to login and APIs return 401

  # =========================================
  # UI + API Tests: RBAC maker cannot self-approve, pool operations
  # =========================================
  @ui @rbac @makerChecker @negative
  Scenario: Prevent maker from assigning approval to self and allow pool pick
    Given I created an approval-required transaction as Agent 'agentA'
    When I try Assign to Specific and choose myself
    Then I should see 'Self-approval not permitted'
    And when I assign to Pool, Checker 'checkerB' can pick the item and approve

  @api @rbac @negative
  Scenario: Direct API attempt by maker to approve is forbidden
    Given the authorization token for 'agentA' is set
    When I send a POST request to '/api/approvals/approve' with payload
      """
      { "transactionId":"X-999","decision":"APPROVE" }
      """
    Then the response status should be 403
    And the response JSON should contain 'error' with 'POLICY_VIOLATION'

  # =========================================
  # UI + API Tests: Foreign trade average price recapture and SEC/TAF fees
  # =========================================
  @api @foreign @fees
  Scenario: EOD broker file re-captures average price and applies SEC/TAF fees
    Given the authorization token for broker ingest API is set
    When I send a POST request to '/api/sim/files/brokerOrderSummary/ingest' with payload
      """
      {
        "orders": [{
          "clientRef":"C-001",
          "symbol":"FOREIGN1",
          "side":"BUY",
          "avgPrice": 25.10,
          "execQty": 200,
          "commission": 5.00,
          "secFee": 0.00,
          "tafFee": 0.00
        }]
      }
      """
    Then the response status should be 202
    And I send a GET request to '/api/orders/search?clientRef=C-001'
    Then the response status should be 200
    And the response JSON should contain 'avgPrice' with 25.10 and 'matched' true

  @ui @foreign
  Scenario: Trade Book shows single average price entry after recapture
    Given I open Trade Book for the customer and filter by symbol 'FOREIGN1'
    Then I should see a single trade entry with the average price and correct executed quantity

  # =========================================
  # API Tests: Reconciliation of TASE files 32/1091 and exception reporting
  # =========================================
  @api @recon @tase
  Scenario: Ingest file 32 and 1091, run reconciliation and generate report
    Given the authorization token for recon API is set
    When I send a POST request to '/api/sim/files/32/ingest' with payload
      """
      { "fileName":"32_D_20240101.dat","checksum":"abc123" }
      """
    Then the response status should be 202
    And I send a POST request to '/api/sim/files/1091/ingest' with payload
      """
      { "fileName":"1091_20240101.dat","checksum":"def456" }
      """
    Then the response status should be 202
    And I send a POST request to '/api/recon/run' with payload
      """
      { "types":["32","1091"] }
      """
    Then the response status should be 202
    And I send a GET request to '/api/recon/report?type=1091&format=csv'
    Then the response status should be 200

  # =========================================
  # UI + API Tests: Tax Simulation to Sell and tax posting on settlement
  # =========================================
  @ui @tax @orders
  Scenario: Tax Simulation -> Sell flow with masked identifiers
    Given I open Account & Portfolio -> Tax Simulation
    When I select symbol '519017', set Quantity '10' and Price '1793' and click 'Simulate'
    Then I should see Profit/Loss and Tax to Pay and a 'Sell' link
    When I click 'Sell' then Preview and Confirm
    Then I should see an internal order number and commission details masked identifiers

  @api @tax @settlement
  Scenario: Settlement triggers tax posting via tax engine integration
    Given the authorization token for file ingest API is set
    When I send a POST request to '/api/sim/files/1051/ingest' with payload
      """
      { "orders":[{"orderId":"TS-001","symbol":"519017","execQty":10,"price":1793}] }
      """
    Then the response status should be 202
    And I send a POST request to '/api/sim/files/1052/ingest' with payload
      """
      { "settlements":[{"orderId":"TS-001","valueDate":"2024-01-02"}] }
      """
    Then the response status should be 202
    And I send a GET request to '/api/tax/postings?orderId=TS-001'
    Then the response status should be 200
    And the response JSON should contain 'posted' true and 'movementType' 'TAX_POSTING'

  # =========================================
  # UI + API Tests: Authorization E-Journal integrity and access control
  # =========================================
  @ui @journal @rbac
  Scenario: E-Journal shows Initiated/Authorized by me and denies cross-user access
    Given I open Authorization -> E-Journal -> 'Initiated By Me'
    Then I should see only items I initiated
    When I switch to 'Authorized By Me'
    Then I should see only items I authorized
    And attempting to open another user's E-Journal via URL should be denied

  @api @journal @immutability @negative
  Scenario: Journal entries are immutable and DELETE/PUT is forbidden
    Given the authorization token for journal API is set
    When I send a DELETE request to '/api/journal/J-123'
    Then the response status should be 403
    And I send a PUT request to '/api/journal/J-123' with payload
      """
      { "attempt":"tamper" }
      """
    Then the response status should be 403

  # =========================================
  # UI + API Tests: Security Rates ingestion and previous close use in transfer valuation
  # =========================================
  @api @rates
  Scenario: Upload security rates for prior day
    Given the authorization token for rates API is set
    When I send a POST request to '/api/rates/upload' with payload
      """
      {
        "asOf":"2024-01-01",
        "rates":[
          {"symbol":"ILS_EQ1","currency":"ILS","close":100.25},
          {"symbol":"USD_EQ2","currency":"USD","close":12.34,"fxToILS":3.60}
        ]
      }
      """
    Then the response status should be 201

  @ui @transfer @valuation
  Scenario: Transfer valuation shows previous close per position and consolidated in account currency
    Given I open Security Transfer -> Add Security
    When I select ILS_EQ1 and USD_EQ2 and set transfer quantities
    Then each row should show Previous Closing Price in trade currency
    And the total transfer value should be shown in account currency (ILS) using t-1 rates
    And no live quote should populate the previous close fields

  # =========================================
  # API Tests: Third-Party Custodian Delivery In/Out (not sent to TASE)
  # =========================================
  @api @thirdParty @transfer
  Scenario: Third-party delivery out/in remains off TASE interfaces and is reported
    Given the authorization token for BO transfer API is set
    When I send a POST request to '/api/transfers' with payload
      """
      { "type":"DELIVERY_OUT", "case":"THIRD_PARTY", "symbol":"FOREIGN1", "qty":50 }
      """
    Then the response status should be 201
    And I send a GET request to '/api/files/outbox?type=15'
    Then the response status should be 200
    And the response JSON should not contain the created transfer id
    And I send a GET request to '/api/reports/thirdPartyTransfers?format=csv'
    Then the response status should be 200
