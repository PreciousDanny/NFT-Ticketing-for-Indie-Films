(define-non-fungible-token film-ticket uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-film-not-found (err u102))
(define-constant err-ticket-not-found (err u103))
(define-constant err-ticket-already-used (err u104))
(define-constant err-event-not-active (err u105))
(define-constant err-insufficient-payment (err u106))
(define-constant err-transfer-failed (err u107))
(define-constant err-minting-disabled (err u108))
(define-constant err-invalid-recipient (err u109))
(define-constant err-already-reviewed (err u110))
(define-constant err-invalid-rating (err u111))
(define-constant err-review-not-found (err u112))
(define-constant err-invalid-pricing-config (err u113))
(define-constant err-pricing-not-enabled (err u114))
(define-constant err-gift-expired (err u115))
(define-constant err-gift-not-found (err u116))
(define-constant err-gift-already-claimed (err u117))
(define-constant err-cannot-gift-to-self (err u118))

(define-data-var last-token-id uint u0)
(define-data-var last-film-id uint u0)
(define-data-var last-gift-id uint u0)
(define-data-var platform-fee-rate uint u250)
(define-data-var default-surge-multiplier uint u150)
(define-data-var default-early-bird-discount uint u80)
(define-data-var default-scarcity-threshold uint u80)

(define-map films uint {
    title: (string-ascii 100),
    creator: principal,
    description: (string-ascii 500),
    poster-uri: (string-ascii 200),
    trailer-uri: (string-ascii 200),
    behind-scenes-uri: (string-ascii 200),
    ticket-price: uint,
    max-tickets: uint,
    sold-tickets: uint,
    event-date: uint,
    venue: (string-ascii 200),
    active: bool
})

(define-map tickets uint {
    film-id: uint,
    owner: principal,
    purchase-date: uint,
    used: bool,
    seat-number: (optional (string-ascii 20)),
    special-edition: bool
})

(define-map user-access principal (list 100 uint))
(define-map film-revenues uint uint)

(define-map film-reviews {user: principal, film-id: uint} {
    rating: uint,
    comment: (string-ascii 500),
    review-date: uint
})

(define-map film-review-stats uint {
    total-reviews: uint,
    average-rating: uint,
    total-rating-points: uint
})

(define-map film-pricing-config uint {
    base-price: uint,
    dynamic-pricing-enabled: bool,
    surge-multiplier: uint,
    early-bird-discount: uint,
    early-bird-deadline: uint,
    scarcity-threshold: uint,
    last-price-update: uint
})

(define-map film-demand-metrics uint {
    recent-purchases: uint,
    demand-score: uint,
    price-history: (list 10 uint)
})

(define-map ticket-gifts uint {
    token-id: uint,
    gifter: principal,
    recipient: principal,
    expiration: uint,
    message: (string-ascii 200),
    claimed: bool
})

(define-map pending-gifts-by-recipient principal (list 50 uint))

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
    (match (map-get? tickets token-id)
        ticket (match (map-get? films (get film-id ticket))
            film (ok (some (get poster-uri film)))
            (err err-film-not-found)
        )
        (err err-ticket-not-found)
    )
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? film-ticket token-id))
)

(define-read-only (get-film (film-id uint))
    (ok (map-get? films film-id))
)

(define-read-only (get-ticket (token-id uint))
    (ok (map-get? tickets token-id))
)

(define-read-only (get-user-tickets (user principal))
    (default-to (list) (map-get? user-access user))
)

(define-read-only (can-access-content (user principal) (film-id uint))
    (let ((user-tickets (get-user-tickets user)))
        (ok (is-some (index-of user-tickets film-id)))
    )
)

(define-read-only (get-film-revenue (film-id uint))
    (ok (default-to u0 (map-get? film-revenues film-id)))
)

(define-read-only (get-platform-fee-rate)
    (ok (var-get platform-fee-rate))
)

(define-read-only (get-film-review (user principal) (film-id uint))
    (ok (map-get? film-reviews {user: user, film-id: film-id}))
)

(define-read-only (get-film-review-stats (film-id uint))
    (ok (map-get? film-review-stats film-id))
)

(define-read-only (has-user-reviewed (user principal) (film-id uint))
    (ok (is-some (map-get? film-reviews {user: user, film-id: film-id})))
)

(define-read-only (get-film-pricing-config (film-id uint))
    (ok (map-get? film-pricing-config film-id))
)

(define-read-only (get-film-demand-metrics (film-id uint))
    (ok (map-get? film-demand-metrics film-id))
)

(define-read-only (calculate-current-price (film-id uint))
    (let (
        (film (unwrap! (map-get? films film-id) err-film-not-found))
        (pricing-config (map-get? film-pricing-config film-id))
        (demand-metrics (default-to {recent-purchases: u0, demand-score: u0, price-history: (list)} 
                                    (map-get? film-demand-metrics film-id)))
    )
        (match pricing-config
            config 
            (if (get dynamic-pricing-enabled config)
                (let (
                    (base-price (get base-price config))
                    (sold-ratio (/ (* (get sold-tickets film) u100) (get max-tickets film)))
                    (blocks-until-event (- (get event-date film) stacks-block-height))
                    (early-bird-active (> blocks-until-event (get early-bird-deadline config)))
                    (is-scarce (>= sold-ratio (get scarcity-threshold config)))
                    (demand-multiplier (if (> (get demand-score demand-metrics) u50) 
                                         (get surge-multiplier config) u100))
                    (scarcity-multiplier (if is-scarce u120 u100))
                    (time-multiplier (if early-bird-active 
                                       (get early-bird-discount config) u100))
                    (final-price (/ (* (* (* base-price demand-multiplier) scarcity-multiplier) time-multiplier) 
                                  u1000000))
                )
                    (ok final-price)
                )
                (ok (get base-price config))
            )
            (ok (get ticket-price film))
        )
    )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (asserts! (is-some (nft-get-owner? film-ticket token-id)) err-ticket-not-found)
        (try! (nft-transfer? film-ticket token-id sender recipient))
        (map-set tickets token-id
            (merge 
                (unwrap-panic (map-get? tickets token-id))
                {owner: recipient}
            )
        )
        (ok true)
    )
)

(define-public (enable-dynamic-pricing 
    (film-id uint)
    (base-price uint)
    (early-bird-deadline uint)
    (custom-surge-multiplier (optional uint))
    (custom-early-bird-discount (optional uint))
    (custom-scarcity-threshold (optional uint))
)
    (let (
        (film (unwrap! (map-get? films film-id) err-film-not-found))
        (surge-mult (default-to (var-get default-surge-multiplier) custom-surge-multiplier))
        (early-discount (default-to (var-get default-early-bird-discount) custom-early-bird-discount))
        (scarcity-thresh (default-to (var-get default-scarcity-threshold) custom-scarcity-threshold))
    )
        (asserts! (is-eq tx-sender (get creator film)) err-owner-only)
        (asserts! (> base-price u0) err-invalid-pricing-config)
        (asserts! (> early-bird-deadline stacks-block-height) err-invalid-pricing-config)
        (asserts! (< early-bird-deadline (get event-date film)) err-invalid-pricing-config)
        
        (map-set film-pricing-config film-id {
            base-price: base-price,
            dynamic-pricing-enabled: true,
            surge-multiplier: surge-mult,
            early-bird-discount: early-discount,
            early-bird-deadline: early-bird-deadline,
            scarcity-threshold: scarcity-thresh,
            last-price-update: stacks-block-height
        })
        
        (map-set film-demand-metrics film-id {
            recent-purchases: u0,
            demand-score: u0,
            price-history: (list base-price)
        })
        
        (ok true)
    )
)

(define-public (update-demand-score (film-id uint))
    (let (
        (current-metrics (default-to {recent-purchases: u0, demand-score: u0, price-history: (list)} 
                                     (map-get? film-demand-metrics film-id)))
        (recent-purchases (get recent-purchases current-metrics))
        (new-score (if (<= (* recent-purchases u10) u100) 
                      (* recent-purchases u10) u100))
        (current-price (unwrap-panic (calculate-current-price film-id)))
        (updated-history (unwrap-panic (as-max-len? 
                           (append (get price-history current-metrics) current-price) u10)))
    )
        (map-set film-demand-metrics film-id {
            recent-purchases: u0,
            demand-score: new-score,
            price-history: updated-history
        })
        (ok new-score)
    )
)

(define-public (create-film 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (poster-uri (string-ascii 200))
    (trailer-uri (string-ascii 200))
    (behind-scenes-uri (string-ascii 200))
    (ticket-price uint)
    (max-tickets uint)
    (event-date uint)
    (venue (string-ascii 200))
)
    (let ((film-id (+ (var-get last-film-id) u1)))
        (map-set films film-id {
            title: title,
            creator: tx-sender,
            description: description,
            poster-uri: poster-uri,
            trailer-uri: trailer-uri,
            behind-scenes-uri: behind-scenes-uri,
            ticket-price: ticket-price,
            max-tickets: max-tickets,
            sold-tickets: u0,
            event-date: event-date,
            venue: venue,
            active: true
        })
        (var-set last-film-id film-id)
        (ok film-id)
    )
)

(define-public (mint-ticket 
    (film-id uint) 
    (recipient principal)
    (seat-number (optional (string-ascii 20)))
    (special-edition bool)
)
    (let (
        (token-id (+ (var-get last-token-id) u1))
        (film (unwrap! (map-get? films film-id) err-film-not-found))
        (current-price (unwrap-panic (calculate-current-price film-id)))
        (platform-fee (/ (* current-price (var-get platform-fee-rate)) u10000))
        (creator-payment (- current-price platform-fee))
        (current-metrics (default-to {recent-purchases: u0, demand-score: u0, price-history: (list)} 
                                     (map-get? film-demand-metrics film-id)))
    )
        (asserts! (get active film) err-event-not-active)
        (asserts! (< (get sold-tickets film) (get max-tickets film)) err-minting-disabled)
        (asserts! (>= (stx-get-balance tx-sender) current-price) err-insufficient-payment)
        
        (try! (stx-transfer? creator-payment tx-sender (get creator film)))
        (try! (stx-transfer? platform-fee tx-sender contract-owner))
        
        (try! (nft-mint? film-ticket token-id recipient))
        
        (map-set tickets token-id {
            film-id: film-id,
            owner: recipient,
            purchase-date: stacks-block-height,
            used: false,
            seat-number: seat-number,
            special-edition: special-edition
        })
        
        (map-set films film-id 
            (merge film {sold-tickets: (+ (get sold-tickets film) u1)})
        )
        
        (let ((current-access (default-to (list) (map-get? user-access recipient))))
            (map-set user-access recipient
                (unwrap-panic (as-max-len? (append current-access film-id) u100))
            )
        )
        
        (map-set film-revenues film-id 
            (+ (default-to u0 (map-get? film-revenues film-id)) creator-payment)
        )
        
        (map-set film-demand-metrics film-id {
            recent-purchases: (+ (get recent-purchases current-metrics) u1),
            demand-score: (get demand-score current-metrics),
            price-history: (get price-history current-metrics)
        })
        
        (var-set last-token-id token-id)
        (ok token-id)
    )
)

(define-public (use-ticket (token-id uint))
    (let ((ticket (unwrap! (map-get? tickets token-id) err-ticket-not-found)))
        (asserts! (is-eq (some tx-sender) (nft-get-owner? film-ticket token-id)) err-not-token-owner)
        (asserts! (not (get used ticket)) err-ticket-already-used)
        
        (map-set tickets token-id (merge ticket {used: true}))
        (ok true)
    )
)

(define-public (toggle-film-status (film-id uint))
    (let ((film (unwrap! (map-get? films film-id) err-film-not-found)))
        (asserts! (is-eq tx-sender (get creator film)) err-owner-only)
        (map-set films film-id (merge film {active: (not (get active film))}))
        (ok (not (get active film)))
    )
)

(define-public (set-platform-fee-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set platform-fee-rate new-rate)
        (ok true)
    )
)

(define-public (withdraw-film-revenue (film-id uint))
    (let (
        (film (unwrap! (map-get? films film-id) err-film-not-found))
        (revenue (default-to u0 (map-get? film-revenues film-id)))
    )
        (asserts! (is-eq tx-sender (get creator film)) err-owner-only)
        (asserts! (> revenue u0) err-invalid-pricing-config)
        
        (try! (as-contract (stx-transfer? revenue tx-sender (get creator film))))
        (map-delete film-revenues film-id)
        (ok revenue)
    )
)

(define-read-only (get-behind-scenes-access (user principal) (film-id uint))
    (let ((user-tickets (get-user-tickets user)))
        (if (is-some (index-of user-tickets film-id))
            (match (map-get? films film-id)
                film (ok (some (get behind-scenes-uri film)))
                (err err-film-not-found)
            )
            (ok none)
        )
    )
)

(define-read-only (get-film-stats (film-id uint))
    (match (map-get? films film-id)
        film (ok {
            total-tickets: (get max-tickets film),
            sold-tickets: (get sold-tickets film),
            revenue: (default-to u0 (map-get? film-revenues film-id)),
            active: (get active film)
        })
        (err err-film-not-found)
    )
)

(define-read-only (is-ticket-valid (token-id uint))
    (match (map-get? tickets token-id)
        ticket (match (map-get? films (get film-id ticket))
            film (ok (and 
                (not (get used ticket))
                (get active film)
                (>= (get event-date film) stacks-block-height)
            ))
            (err err-film-not-found)
        )
        (err err-ticket-not-found)
    )
)

(define-public (submit-film-review (film-id uint) (rating uint) (comment (string-ascii 500)))
    (let (
        (user-tickets (get-user-tickets tx-sender))
        (current-stats (default-to {total-reviews: u0, average-rating: u0, total-rating-points: u0} 
                                    (map-get? film-review-stats film-id)))
        (new-total-reviews (+ (get total-reviews current-stats) u1))
        (new-total-points (+ (get total-rating-points current-stats) rating))
        (new-average (/ new-total-points new-total-reviews))
    )
        (asserts! (is-some (map-get? films film-id)) err-film-not-found)
        (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-rating)
        (asserts! (is-some (index-of user-tickets film-id)) err-not-token-owner)
        (asserts! (is-none (map-get? film-reviews {user: tx-sender, film-id: film-id})) err-already-reviewed)
        
        (map-set film-reviews {user: tx-sender, film-id: film-id} {
            rating: rating,
            comment: comment,
            review-date: stacks-block-height
        })
        
        (map-set film-review-stats film-id {
            total-reviews: new-total-reviews,
            average-rating: new-average,
            total-rating-points: new-total-points
        })
        
        (ok true)
    )
)

(define-read-only (get-gift (gift-id uint))
    (ok (map-get? ticket-gifts gift-id))
)

(define-read-only (get-pending-gifts (recipient principal))
    (ok (default-to (list) (map-get? pending-gifts-by-recipient recipient)))
)

(define-read-only (is-gift-valid (gift-id uint))
    (match (map-get? ticket-gifts gift-id)
        gift (ok (and 
            (not (get claimed gift))
            (> (get expiration gift) stacks-block-height)
        ))
        (err err-gift-not-found)
    )
)

(define-public (create-ticket-gift 
    (token-id uint) 
    (recipient principal) 
    (expiration-blocks uint)
    (message (string-ascii 200))
)
    (let (
        (gift-id (+ (var-get last-gift-id) u1))
        (ticket (unwrap! (map-get? tickets token-id) err-ticket-not-found))
        (expiration (+ stacks-block-height expiration-blocks))
        (current-pending (default-to (list) (map-get? pending-gifts-by-recipient recipient)))
    )
        (asserts! (is-eq (some tx-sender) (nft-get-owner? film-ticket token-id)) err-not-token-owner)
        (asserts! (not (is-eq tx-sender recipient)) err-cannot-gift-to-self)
        (asserts! (not (get used ticket)) err-ticket-already-used)
        
        (try! (nft-transfer? film-ticket token-id tx-sender (as-contract tx-sender)))
        
        (map-set ticket-gifts gift-id {
            token-id: token-id,
            gifter: tx-sender,
            recipient: recipient,
            expiration: expiration,
            message: message,
            claimed: false
        })
        
        (map-set pending-gifts-by-recipient recipient
            (unwrap-panic (as-max-len? (append current-pending gift-id) u50))
        )
        
        (var-set last-gift-id gift-id)
        (ok gift-id)
    )
)

(define-public (claim-gift (gift-id uint))
    (let (
        (gift (unwrap! (map-get? ticket-gifts gift-id) err-gift-not-found))
        (token-id (get token-id gift))
        (ticket (unwrap! (map-get? tickets token-id) err-ticket-not-found))
    )
        (asserts! (is-eq tx-sender (get recipient gift)) err-not-token-owner)
        (asserts! (not (get claimed gift)) err-gift-already-claimed)
        (asserts! (> (get expiration gift) stacks-block-height) err-gift-expired)
        
        (try! (as-contract (nft-transfer? film-ticket token-id tx-sender (get recipient gift))))
        
        (map-set tickets token-id (merge ticket {owner: tx-sender}))
        
        (map-set ticket-gifts gift-id (merge gift {claimed: true}))
        
        (let ((current-access (default-to (list) (map-get? user-access tx-sender))))
            (map-set user-access tx-sender
                (unwrap-panic (as-max-len? (append current-access (get film-id ticket)) u100))
            )
        )
        
        (ok token-id)
    )
)

(define-public (revoke-gift (gift-id uint))
    (let (
        (gift (unwrap! (map-get? ticket-gifts gift-id) err-gift-not-found))
        (token-id (get token-id gift))
    )
        (asserts! (is-eq tx-sender (get gifter gift)) err-not-token-owner)
        (asserts! (not (get claimed gift)) err-gift-already-claimed)
        
        (try! (as-contract (nft-transfer? film-ticket token-id tx-sender (get gifter gift))))
        
        (map-set ticket-gifts gift-id (merge gift {claimed: true}))
        
        (ok token-id)
    )
)
