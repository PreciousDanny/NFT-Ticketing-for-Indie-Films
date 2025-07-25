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

(define-data-var last-token-id uint u0)
(define-data-var last-film-id uint u0)
(define-data-var platform-fee-rate uint u250)

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
        (platform-fee (/ (* (get ticket-price film) (var-get platform-fee-rate)) u10000))
        (creator-payment (- (get ticket-price film) platform-fee))
    )
        (asserts! (get active film) err-event-not-active)
        (asserts! (< (get sold-tickets film) (get max-tickets film)) err-minting-disabled)
        (asserts! (>= (stx-get-balance tx-sender) (get ticket-price film)) err-insufficient-payment)
        
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
        (asserts! (> revenue u0) (err u110))
        
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
