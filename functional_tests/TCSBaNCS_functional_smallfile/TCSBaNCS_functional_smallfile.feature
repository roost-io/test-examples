Feature: TCS BaNCS Call Center Security and Functional Testing

  # API Test Scenarios
  @api
  Scenario Outline: Agent Login with MFA
    Given the API base URL is '/api/auth'
    And the authorization token is set
    When I send a POST request to '/login' with payload
      """
      {
        "username": "<username>",
        "password": "<password>"
      }
      """
    Then the response status should be 200
    And I receive an MFA code via registered method
    When I send a POST request to '/mfa/verify' with payload
      """
      {
        "mfa_code": "<mfa_code>"
      }
      """
    Then the response status should be 200
    And the response should contain 'dashboard'

    Examples:
      | username | password | mfa_code |
      | agent1   | pass123  | 123456   |
      | agent2   | pass456  | 654321   |

  Scenario Outline: Customer Verification via OTP
    Given the API base URL is '/api/verification'
    And the authorization token is set
    When I send a POST request to '/otp/send' with payload
      """
      {
        "customer_id": "<customer_id>"
      }
      """
    Then the response status should be 200
    And the OTP is sent to the customer's phone
    When I send a POST request to '/otp/verify' with payload
      """
      {
        "otp": "<otp>"
      }
      """
    Then the response status should be <status>
    And the response should contain '<verification_result>'

    Examples:
      | customer_id | otp    | status | verification_result |
      | 12345       | 111111 | 200    | verified            |
      | 12345       | 000000 | 400    | failed              |

  Scenario Outline: Sensitive Profile Change - Email Update
    Given the API base URL is '/api/profile'
    And the authorization token is set
    When I send a PUT request to '/email/update' with payload
      """
      {
        "new_email": "<new_email>"
      }
      """
    Then the response status should be 200
    And the response should contain 'email updated'
    And the change is logged with re-authentication details

    Examples:
      | new_email         |
      | newemail@domain.com |
      | another@domain.com  |

  Scenario Outline: Payment Transfer with Beneficiary Addition
    Given the API base URL is '/api/payments'
    And the authorization token is set
    When I send a POST request to '/transfer' with payload
      """
      {
        "amount": "<amount>",
        "beneficiary": {
          "name": "<beneficiary_name>",
          "account_number": "<account_number>"
        }
      }
      """
    Then the response status should be 200
    And the response should contain 'transfer successful'
    And beneficiary addition is logged

    Examples:
      | amount | beneficiary_name | account_number |
      | 1000   | John Doe         | 1234567890     |
      | 500    | Jane Smith       | 0987654321     |

  Scenario Outline: Card Block/Unblock
    Given the API base URL is '/api/cards'
    And the authorization token is set
    When I send a POST request to '/block' with payload
      """
      {
        "card_id": "<card_id>"
      }
      """
    Then the response status should be 200
    And the response should contain 'card blocked'
    And the block action is logged
    When I send a POST request to '/unblock' with payload
      """
      {
        "card_id": "<card_id>"
      }
      """
    Then the response status should be 200
    And the response should contain 'card unblocked'
    And the unblock action is logged

    Examples:
      | card_id |
      | 1111    |
      | 2222    |

  Scenario Outline: Case/Dispute Creation
    Given the API base URL is '/api/disputes'
    And the authorization token is set
    When I send a POST request to '/create' with payload
      """
      {
        "transaction_id": "<transaction_id>",
        "details": "<details>"
      }
      """
    Then the response status should be 201
    And the response should contain 'dispute created'
    And the details are logged

    Examples:
      | transaction_id | details           |
      | 98765          | Dispute overcharge |
      | 54321          | Unauthorized charge|

  Scenario Outline: Call Recording Access Control
    Given the API base URL is '/api/recordings'
    And the authorization token is set
    When I send a GET request to '/play/<recording_id>'
    Then the response status should be 200
    And the response should contain 'recording played'
    And access is logged

    Examples:
      | recording_id |
      | rec123       |
      | rec456       |

  Scenario Outline: Secure Error Handling
    Given the API base URL is '/api/transactions'
    And the authorization token is set
    When I send a POST request to '/process' with payload
      """
      {
        "transaction_id": "<transaction_id>"
      }
      """
    Then the response status should be 400
    And the error message should be generic
    And the error is logged

    Examples:
      | transaction_id |
      | 99999          |
      | 88888          |

  Scenario Outline: Session Timeout and Re-authentication
    Given the API base URL is '/api/session'
    And the authorization token is set
    When I remain inactive for the session timeout period
    And I attempt to perform an action
    Then the response status should be 401
    And I must re-authenticate
    And the session timeout is logged

    Examples:
      | action |
      | view   |
      | edit   |

  Scenario Outline: Authorization and Role-Based Access Control
    Given the API base URL is '/api/access'
    And the authorization token is set
    When I send a GET request to '/restricted/<feature>'
    Then the response status should be 403
    And the access attempt is logged

    Examples:
      | feature |
      | admin   |
      | reports |

  Scenario Outline: Agent Account Lockout After Failed Login Attempts
    Given the API base URL is '/api/auth'
    And the authorization token is set
    When I send a POST request to '/login' with payload
      """
      {
        "username": "<username>",
        "password": "<wrong_password>"
      }
      """
    Then the response status should be 401
    And I repeat the login attempt until lockout
    Then the response status should be 423
    And the account lockout is logged

    Examples:
      | username | wrong_password |
      | agent1   | wrongpass1     |
      | agent2   | wrongpass2     |

  # UI Test Scenarios
  @ui
  Scenario Outline: Agent Login with MFA via UI
    Given I am on the 'login' page
    When I enter '<username>' in the 'username' field
    And I enter '<password>' in the 'password' field
    And I click the 'Login' button
    Then I should see 'Enter MFA code'
    When I enter '<mfa_code>' in the 'MFA code' field
    And I click the 'Submit' button
    Then I should be redirected to the 'dashboard'

    Examples:
      | username | password | mfa_code |
      | agent1   | pass123  | 123456   |
      | agent2   | pass456  | 654321   |

  Scenario Outline: Customer Verification via OTP UI
    Given I am on the 'verification' page
    When I enter '<customer_id>' in the 'customer ID' field
    And I click the 'Send OTP' button
    Then I should see 'OTP sent'
    When I enter '<otp>' in the 'OTP' field
    And I click the 'Verify' button
    Then I should see '<verification_result>'

    Examples:
      | customer_id | otp    | verification_result |
      | 12345       | 111111 | verified            |
      | 12345       | 000000 | failed              |

  Scenario Outline: Sensitive Profile Change - Email Update via UI
    Given I am on the 'profile' page
    When I click the 'Update Email' button
    And I enter '<new_email>' in the 'new email' field
    And I click the 'Submit' button
    Then I should see 'Email updated successfully'

    Examples:
      | new_email         |
      | newemail@domain.com |
      | another@domain.com  |

  Scenario Outline: Payment Transfer with Beneficiary Addition via UI
    Given I am on the 'payments' page
    When I click the 'Transfer' button
    And I enter '<amount>' in the 'amount' field
    And I enter '<beneficiary_name>' in the 'beneficiary name' field
    And I enter '<account_number>' in the 'account number' field
    And I click the 'Submit' button
    Then I should see 'Transfer successful'

    Examples:
      | amount | beneficiary_name | account_number |
      | 1000   | John Doe         | 1234567890     |
      | 500    | Jane Smith       | 0987654321     |

  Scenario Outline: Card Block/Unblock via UI
    Given I am on the 'card management' page
    When I click the 'Block Card' button
    Then I should see 'Card blocked'
    When I click the 'Unblock Card' button
    Then I should see 'Card unblocked'

    Examples:
      | card_id |
      | 1111    |
      | 2222    |

  Scenario Outline: Case/Dispute Creation via UI
    Given I am on the 'dispute management' page
    When I select '<transaction_id>' for dispute
    And I enter '<details>' in the 'dispute details' field
    And I click the 'Submit' button
    Then I should see 'Dispute created successfully'

    Examples:
      | transaction_id | details           |
      | 98765          | Dispute overcharge |
      | 54321          | Unauthorized charge|

  Scenario Outline: Call Recording Access Control via UI
    Given I am on the 'call recordings' page
    When I search for '<recording_id>'
    And I click the 'Play' button
    Then I should see 'Recording played'

    Examples:
      | recording_id |
      | rec123       |
      | rec456       |

  Scenario Outline: Secure Error Handling via UI
    Given I am on the 'transactions' page
    When I perform an action that triggers an error
    Then I should see a generic error message

    Examples:
      | action |
      | view   |
      | edit   |

  Scenario Outline: Session Timeout and Re-authentication via UI
    Given I am on the 'dashboard' page
    When I remain inactive for the session timeout period
    And I attempt to perform an action
    Then I should see 'Session expired, please re-authenticate'

    Examples:
      | action |
      | view   |
      | edit   |

  Scenario Outline: Authorization and Role-Based Access Control via UI
    Given I am on the 'access control' page
    When I attempt to access '<feature>'
    Then I should see 'Access denied'

    Examples:
      | feature |
      | admin   |
      | reports |

  Scenario Outline: Agent Account Lockout After Failed Login Attempts via UI
    Given I am on the 'login' page
    When I enter '<username>' in the 'username' field
    And I enter '<wrong_password>' in the 'password' field
    And I click the 'Login' button
    Then I should see 'Incorrect credentials'
    And I repeat the login attempt until lockout
    Then I should see 'Account locked'

    Examples:
      | username | wrong_password |
      | agent1   | wrongpass1     |
      | agent2   | wrongpass2     |
