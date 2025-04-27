;; AdChain - A privacy-focused digital advertising platform
;; Users opt-in to view ads and receive direct compensation without intermediaries

;; Data storage
(define-map user-profiles principal {
  active: bool,
  preferences: (list 10 uint),
  earnings: uint,
  last-payout: uint,
  ad-view-count: uint
})

(define-map ad-campaigns uint {
  owner: principal,
  budget: uint,
  cost-per-view: uint,
  active: bool,
  category: uint,
  total-views: uint,
  created-at: uint
})

(define-map ad-views {user: principal, ad-id: uint} {
  timestamp: uint,
  compensated: bool
})

(define-map categories uint (string-ascii 64))

;; Constants
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_PARAMS (err u101))
(define-constant ERR_USER_NOT_FOUND (err u102))
(define-constant ERR_CAMPAIGN_NOT_FOUND (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERR_ALREADY_REGISTERED (err u105))
(define-constant ERR_ALREADY_VIEWED (err u106))
(define-constant ERR_INVALID_PRINCIPAL (err u107))
(define-constant ERR_INVALID_VALUE (err u108))
(define-constant ERR_CATEGORY_NOT_FOUND (err u109))

(define-constant ZERO_ADDRESS 'SP000000000000000000002Q6VF78)
(define-constant MIN_COST_PER_VIEW u1)
(define-constant MAX_COST_PER_VIEW u1000)
(define-constant MIN_CAMPAIGN_BUDGET u1000)

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var next-campaign-id uint u1)
(define-data-var platform-fee-percent uint u5) ;; 5% fee
(define-data-var platform-balance uint u0)

;; Admin functions
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (not (is-eq new-owner ZERO_ADDRESS)) ERR_INVALID_PRINCIPAL)
    (ok (var-set contract-owner new-owner))))

(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-fee u20) ERR_INVALID_PARAMS) ;; Max 20% fee
    (ok (var-set platform-fee-percent new-fee))))

(define-public (add-category (category-id uint) (category-name (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (> (len category-name) u0) ERR_INVALID_PARAMS)
    (ok (map-set categories category-id category-name))))

;; User functions
(define-public (register-user (preferences (list 10 uint)))
  (begin
    (asserts! (is-none (map-get? user-profiles tx-sender)) ERR_ALREADY_REGISTERED)
    (asserts! (validate-preferences preferences) ERR_INVALID_PARAMS)
    (ok (map-set user-profiles tx-sender {
      active: true,
      preferences: preferences,
      earnings: u0,
      last-payout: u0,
      ad-view-count: u0
    }))))

(define-public (update-preferences (preferences (list 10 uint)))
  (let ((user-profile (unwrap! (map-get? user-profiles tx-sender) ERR_USER_NOT_FOUND)))
    (asserts! (validate-preferences preferences) ERR_INVALID_PARAMS)
    (ok (map-set user-profiles tx-sender (merge user-profile {preferences: preferences})))))

(define-public (opt-out)
  (let ((user-profile (unwrap! (map-get? user-profiles tx-sender) ERR_USER_NOT_FOUND)))
    (ok (map-set user-profiles tx-sender (merge user-profile {active: false})))))

(define-public (opt-in)
  (let ((user-profile (unwrap! (map-get? user-profiles tx-sender) ERR_USER_NOT_FOUND)))
    (ok (map-set user-profiles tx-sender (merge user-profile {active: true})))))

;; Advertiser functions
(define-public (create-ad-campaign (budget uint) (cost-per-view uint) (category uint) (stx-amount uint))
  (begin
    (asserts! (>= budget MIN_CAMPAIGN_BUDGET) ERR_INVALID_PARAMS)
    (asserts! (and (>= cost-per-view MIN_COST_PER_VIEW) (<= cost-per-view MAX_COST_PER_VIEW)) ERR_INVALID_PARAMS)
    (asserts! (is-some (map-get? categories category)) ERR_CATEGORY_NOT_FOUND)
    (asserts! (>= stx-amount budget) ERR_INSUFFICIENT_FUNDS)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? stx-amount tx-sender (as-contract tx-sender)))
    
    (let ((campaign-id (var-get next-campaign-id)))
      ;; Create campaign
      (map-set ad-campaigns campaign-id {
        owner: tx-sender,
        budget: budget,
        cost-per-view: cost-per-view,
        active: true,
        category: category,
        total-views: u0,
        created-at: block-height
      })
      
      ;; Increment campaign ID
      (var-set next-campaign-id (+ campaign-id u1))
      (ok campaign-id))))

(define-public (pause-campaign (campaign-id uint))
  (let ((campaign (unwrap! (map-get? ad-campaigns campaign-id) ERR_CAMPAIGN_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner campaign)) ERR_NOT_AUTHORIZED)
    (ok (map-set ad-campaigns campaign-id (merge campaign {active: false})))))

(define-public (resume-campaign (campaign-id uint))
  (let ((campaign (unwrap! (map-get? ad-campaigns campaign-id) ERR_CAMPAIGN_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner campaign)) ERR_NOT_AUTHORIZED)
    (ok (map-set ad-campaigns campaign-id (merge campaign {active: true})))))

(define-public (add-campaign-budget (campaign-id uint) (additional-budget uint))
  (let ((campaign (unwrap! (map-get? ad-campaigns campaign-id) ERR_CAMPAIGN_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner campaign)) ERR_NOT_AUTHORIZED)
    (asserts! (> additional-budget u0) ERR_INVALID_PARAMS)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? additional-budget tx-sender (as-contract tx-sender)))
    
    (ok (map-set ad-campaigns campaign-id 
      (merge campaign {budget: (+ (get budget campaign) additional-budget)})))))

;; Ad viewing and compensation
(define-public (record-ad-view (campaign-id uint))
  (let (
    (user-profile (unwrap! (map-get? user-profiles tx-sender) ERR_USER_NOT_FOUND))
    (campaign (unwrap! (map-get? ad-campaigns campaign-id) ERR_CAMPAIGN_NOT_FOUND))
    (view-key {user: tx-sender, ad-id: campaign-id})
  )
    ;; Validate conditions
    (asserts! (get active user-profile) ERR_USER_NOT_FOUND)
    (asserts! (get active campaign) ERR_CAMPAIGN_NOT_FOUND)
    (asserts! (is-none (map-get? ad-views view-key)) ERR_ALREADY_VIEWED)
    (asserts! (>= (get budget campaign) (get cost-per-view campaign)) ERR_INSUFFICIENT_FUNDS)
    (asserts! (contains (get category campaign) (get preferences user-profile)) ERR_INVALID_PARAMS)
    
    ;; Calculate compensation
    (let (
      (cost-per-view (get cost-per-view campaign))
      (platform-fee (/ (* cost-per-view (var-get platform-fee-percent)) u100))
      (user-compensation (- cost-per-view platform-fee))
    )
      ;; Record the view
      (map-set ad-views view-key {timestamp: block-height, compensated: true})
      
      ;; Update campaign stats
      (map-set ad-campaigns campaign-id (merge campaign {
        budget: (- (get budget campaign) cost-per-view),
        total-views: (+ (get total-views campaign) u1)
      }))
      
      ;; Update user stats
      (map-set user-profiles tx-sender (merge user-profile {
        earnings: (+ (get earnings user-profile) user-compensation),
        ad-view-count: (+ (get ad-view-count user-profile) u1)
      }))
      
      ;; Update platform balance
      (var-set platform-balance (+ (var-get platform-balance) platform-fee))
      
      (ok user-compensation))))

(define-public (withdraw-earnings)
  (let ((user-profile (unwrap! (map-get? user-profiles tx-sender) ERR_USER_NOT_FOUND)))
    (let ((earnings (get earnings user-profile)))
      (asserts! (> earnings u0) ERR_INSUFFICIENT_FUNDS)
      
      ;; Transfer STX to user
      (try! (as-contract (stx-transfer? earnings tx-sender tx-sender)))
      
      ;; Update user profile
      (map-set user-profiles tx-sender (merge user-profile {
        earnings: u0,
        last-payout: block-height
      }))
      
      (ok earnings))))

(define-public (withdraw-platform-fees)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (let ((amount (var-get platform-balance)))
      (asserts! (> amount u0) ERR_INSUFFICIENT_FUNDS)
      
      ;; Transfer STX to contract owner
      (try! (as-contract (stx-transfer? amount tx-sender (var-get contract-owner))))
      
      ;; Reset platform balance
      (var-set platform-balance u0)
      
      (ok amount))))

;; Helper functions
(define-private (validate-preferences (preferences (list 10 uint)))
  (let ((prefs-len (len preferences)))
    (and 
      (> prefs-len u0)
      (<= prefs-len u10)
      (is-eq prefs-len (len (filter is-valid-category preferences))))))

(define-private (is-valid-category (category uint))
  (is-some (map-get? categories category)))

(define-private (contains (item uint) (lst (list 10 uint)))
  (default-to false (some (lambda (x) (is-eq x item)) lst)))

;; Read-only functions
(define-read-only (get-user-profile (user principal))
  (map-get? user-profiles user))

(define-read-only (get-campaign (campaign-id uint))
  (map-get? ad-campaigns campaign-id))

(define-read-only (get-category (category-id uint))
  (map-get? categories category-id))

(define-read-only (get-platform-fee)
  (var-get platform-fee-percent))

(define-read-only (get-platform-balance)
  (var-get platform-balance))

(define-read-only (get-ad-view (user principal) (campaign-id uint))
  (map-get? ad-views {user: user, ad-id: campaign-id}))