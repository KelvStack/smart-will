
;; title: smart-will
;; version: 1.0.0
;; summary: A blockchain-based digital estate planning platform for secure asset inheritance
;; description: SmartWill enables users to create digital wills with beneficiary management,
;;              asset distribution, time locks, and social recovery features

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_INVALID_PERCENTAGE (err u400))
(define-constant ERR_WILL_ALREADY_EXECUTED (err u410))
(define-constant ERR_WILL_NOT_READY (err u411))
(define-constant ERR_INSUFFICIENT_BALANCE (err u412))
(define-constant ERR_INVALID_BENEFICIARY (err u413))
(define-constant ERR_MAX_BENEFICIARIES_REACHED (err u414))
(define-constant ERR_PERCENTAGE_TOTAL_INVALID (err u415))
(define-constant ERR_BENEFICIARY_EXISTS (err u416))
(define-constant ERR_TIME_LOCK_ACTIVE (err u417))
(define-constant ERR_INSUFFICIENT_GUARDIANS (err u418))
(define-constant ERR_GUARDIAN_ALREADY_EXISTS (err u419))
(define-constant ERR_NOT_GUARDIAN (err u420))
(define-constant ERR_HEARTBEAT_EXPIRED (err u421))
(define-constant ERR_EXECUTION_BLOCKED (err u422))

;; Maximum number of beneficiaries per will
(define-constant MAX_BENEFICIARIES u10)

;; Maximum number of guardians per will
(define-constant MAX_GUARDIANS u5)

;; Minimum time lock period (30 days in blocks)
(define-constant MIN_TIME_LOCK u4320)

;; Heartbeat timeout period (180 days in blocks)
(define-constant HEARTBEAT_TIMEOUT u25920)

;; data vars
(define-data-var next-will-id uint u1)
(define-data-var contract-fee uint u1000000) ;; 1 STX fee for will creation

;; data maps
;; Main will storage
(define-map wills
    uint ;; will-id
    {
        creator: principal,
        is-active: bool,
        created-at: uint,
        last-updated: uint,
        total-stx-amount: uint,
        beneficiary-count: uint,
        is-executed: bool,
        execution-block: (optional uint),
        metadata-uri: (optional (string-ascii 256)),
    }
)

;; User to will mapping (one will per user for now)
(define-map user-will
    principal ;; user address
    uint ;; will-id
)

;; Will ownership verification
(define-map will-owners
    uint ;; will-id
    principal ;; owner address
)

;; Beneficiary management
(define-map beneficiaries
    {
        will-id: uint,
        beneficiary-address: principal,
    }
    ;; composite key
    {
        percentage: uint, ;; Percentage allocation (0-10000 for 0-100.00%)
        is-active: bool,
        added-at: uint,
        notes: (optional (string-ascii 256)),
    }
)

;; Track beneficiary addresses for each will
(define-map will-beneficiary-list
    uint ;; will-id
    (list 10 principal) ;; list of beneficiary addresses
)

;; Beneficiary count per will (for quick access)
(define-map beneficiary-counts
    uint ;; will-id
    uint ;; count
)

;; Time lock settings for wills
(define-map will-time-locks
    uint ;; will-id
    {
        is-enabled: bool,
        lock-duration: uint, ;; in blocks
        unlock-block: (optional uint),
        created-by: principal,
    }
)

;; Guardian system for social recovery
(define-map guardians
    {
        will-id: uint,
        guardian-address: principal,
    }
    ;; composite key
    {
        is-active: bool,
        added-at: uint,
        guardian-name: (optional (string-ascii 64)),
    }
)

;; Guardian list per will
(define-map will-guardian-list
    uint ;; will-id
    (list 5 principal) ;; list of guardian addresses
)

;; Heartbeat system for liveness detection
(define-map will-heartbeats
    uint ;; will-id
    {
        last-heartbeat: uint,
        is-active: bool,
        timeout-duration: uint, ;; in blocks
    }
)

;; Emergency execution requests
(define-map emergency-executions
    uint ;; will-id
    {
        requested-by: principal,
        requested-at: uint,
        guardian-approvals: uint,
        required-approvals: uint,
        is-approved: bool,
    }
)

;; public functions

;; Create a new digital will
(define-public (create-will (metadata-uri (optional (string-ascii 256))))
    (let (
            (caller tx-sender)
            (will-id (var-get next-will-id))
            (current-block stacks-block-height)
        )
        ;; Check if user already has a will
        (asserts! (is-none (map-get? user-will caller)) ERR_ALREADY_EXISTS)

        ;; Transfer contract fee
        (try! (stx-transfer? (var-get contract-fee) caller CONTRACT_OWNER))

        ;; Create the will record
        (map-set wills will-id {
            creator: caller,
            is-active: true,
            created-at: current-block,
            last-updated: current-block,
            total-stx-amount: u0,
            beneficiary-count: u0,
            is-executed: false,
            execution-block: none,
            metadata-uri: metadata-uri,
        })

        ;; Map user to will
        (map-set user-will caller will-id)
        (map-set will-owners will-id caller)

        ;; Increment will counter
        (var-set next-will-id (+ will-id u1))

        (ok will-id)
    )
)

;; Update will metadata
(define-public (update-will-metadata
        (will-id uint)
        (new-metadata-uri (optional (string-ascii 256)))
    )
    (let (
            (caller tx-sender)
            (will-data (unwrap! (map-get? wills will-id) ERR_NOT_FOUND))
        )
        ;; Verify ownership
        (asserts! (is-eq caller (get creator will-data)) ERR_UNAUTHORIZED)

        ;; Ensure will is not executed
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)

        ;; Update the will
        (map-set wills will-id
            (merge will-data {
                last-updated: stacks-block-height,
                metadata-uri: new-metadata-uri,
            })
        )

        (ok true)
    )
)

;; Activate or deactivate a will
(define-public (toggle-will-status (will-id uint))
    (let (
            (caller tx-sender)
            (will-data (unwrap! (map-get? wills will-id) ERR_NOT_FOUND))
        )
        ;; Verify ownership
        (asserts! (is-eq caller (get creator will-data)) ERR_UNAUTHORIZED)

        ;; Ensure will is not executed
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)

        ;; Toggle status
        (map-set wills will-id
            (merge will-data {
                is-active: (not (get is-active will-data)),
                last-updated: stacks-block-height,
            })
        )

        (ok (not (get is-active will-data)))
    )
)

;; Deposit STX into will
(define-public (deposit-stx
        (will-id uint)
        (amount uint)
    )
    (let (
            (caller tx-sender)
            (will-data (unwrap! (map-get? wills will-id) ERR_NOT_FOUND))
        )
        ;; Verify ownership
        (asserts! (is-eq caller (get creator will-data)) ERR_UNAUTHORIZED)

        ;; Ensure will is active and not executed
        (asserts! (get is-active will-data) ERR_WILL_NOT_READY)
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)

        ;; Ensure amount is greater than 0
        (asserts! (> amount u0) ERR_INSUFFICIENT_BALANCE)

        ;; Transfer STX to contract
        (try! (stx-transfer? amount caller (as-contract tx-sender)))

        ;; Update will balance
        (map-set wills will-id
            (merge will-data {
                total-stx-amount: (+ (get total-stx-amount will-data) amount),
                last-updated: stacks-block-height,
            })
        )

        (ok true)
    )
)

;; Add a beneficiary to a will
(define-public (add-beneficiary
        (will-id uint)
        (beneficiary-address principal)
        (percentage uint)
        (notes (optional (string-ascii 256)))
    )
    (let (
            (caller tx-sender)
            (will-data (unwrap! (map-get? wills will-id) ERR_NOT_FOUND))
            (current-beneficiaries (default-to (list) (map-get? will-beneficiary-list will-id)))
            (beneficiary-count (get beneficiary-count will-data))
        )
        ;; Verify ownership
        (asserts! (is-eq caller (get creator will-data)) ERR_UNAUTHORIZED)

        ;; Ensure will is not executed
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)

        ;; Check beneficiary limit
        (asserts! (< beneficiary-count MAX_BENEFICIARIES)
            ERR_MAX_BENEFICIARIES_REACHED
        )

        ;; Validate percentage (0-10000 for 0-100.00%)
        (asserts! (<= percentage u10000) ERR_INVALID_PERCENTAGE)
        (asserts! (> percentage u0) ERR_INVALID_PERCENTAGE)

        ;; Ensure beneficiary doesn't already exist
        (asserts!
            (is-none (map-get? beneficiaries {
                will-id: will-id,
                beneficiary-address: beneficiary-address,
            }))
            ERR_BENEFICIARY_EXISTS
        )

        ;; Validate total percentage doesn't exceed 100%
        (let ((new-total (+ (get-total-percentage will-id) percentage)))
            (asserts! (<= new-total u10000) ERR_PERCENTAGE_TOTAL_INVALID)
        )

        ;; Add beneficiary
        (map-set beneficiaries {
            will-id: will-id,
            beneficiary-address: beneficiary-address,
        } {
            percentage: percentage,
            is-active: true,
            added-at: stacks-block-height,
            notes: notes,
        })

        ;; Update beneficiary list
        (map-set will-beneficiary-list will-id
            (unwrap!
                (as-max-len? (append current-beneficiaries beneficiary-address)
                    u10
                )
                ERR_MAX_BENEFICIARIES_REACHED
            ))

        ;; Update will beneficiary count
        (map-set wills will-id
            (merge will-data {
                beneficiary-count: (+ beneficiary-count u1),
                last-updated: stacks-block-height,
            })
        )

        (ok true)
    )
)

;; Remove a beneficiary from a will
(define-public (remove-beneficiary
        (will-id uint)
        (beneficiary-address principal)
    )
    (let (
            (caller tx-sender)
            (will-data (unwrap! (map-get? wills will-id) ERR_NOT_FOUND))
            (beneficiary-data (unwrap!
                (map-get? beneficiaries {
                    will-id: will-id,
                    beneficiary-address: beneficiary-address,
                })
                ERR_NOT_FOUND
            ))
            (beneficiary-count (get beneficiary-count will-data))
        )
        ;; Verify ownership
        (asserts! (is-eq caller (get creator will-data)) ERR_UNAUTHORIZED)

        ;; Ensure will is not executed
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)

        ;; Remove beneficiary
        (map-delete beneficiaries {
            will-id: will-id,
            beneficiary-address: beneficiary-address,
        })

        ;; Note: For simplicity, we'll rebuild the beneficiary list when needed
        ;; In a production environment, you'd implement proper list management

        ;; Update will beneficiary count
        (map-set wills will-id
            (merge will-data {
                beneficiary-count: (- beneficiary-count u1),
                last-updated: stacks-block-height,
            })
        )

        (ok true)
    )
)

;; Update beneficiary percentage
(define-public (update-beneficiary-percentage
        (will-id uint)
        (beneficiary-address principal)
        (new-percentage uint)
    )
    (let (
            (caller tx-sender)
            (will-data (unwrap! (map-get? wills will-id) ERR_NOT_FOUND))
            (beneficiary-data (unwrap!
                (map-get? beneficiaries {
                    will-id: will-id,
                    beneficiary-address: beneficiary-address,
                })
                ERR_NOT_FOUND
            ))
            (old-percentage (get percentage beneficiary-data))
        )
        ;; Verify ownership
        (asserts! (is-eq caller (get creator will-data)) ERR_UNAUTHORIZED)

        ;; Ensure will is not executed
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)

        ;; Validate percentage
        (asserts! (<= new-percentage u10000) ERR_INVALID_PERCENTAGE)
        (asserts! (> new-percentage u0) ERR_INVALID_PERCENTAGE)

        ;; Validate total percentage doesn't exceed 100%
        (let (
                (current-total (get-total-percentage will-id))
                (adjusted-total (+ (- current-total old-percentage) new-percentage))
            )
            (asserts! (<= adjusted-total u10000) ERR_PERCENTAGE_TOTAL_INVALID)
        )

        ;; Update beneficiary
        (map-set beneficiaries {
            will-id: will-id,
            beneficiary-address: beneficiary-address,
        }
            (merge beneficiary-data { percentage: new-percentage })
        )

        ;; Update will timestamp
        (map-set wills will-id
            (merge will-data { last-updated: stacks-block-height })
        )

        (ok true)
    )
)

;; Distribute assets to beneficiaries (simplified STX distribution)
(define-public (distribute-assets (will-id uint))
    (let (
            (caller tx-sender)
            (will-data (unwrap! (map-get? wills will-id) ERR_NOT_FOUND))
            (total-amount (get total-stx-amount will-data))
            (beneficiary-list (default-to (list) (map-get? will-beneficiary-list will-id)))
        )
        ;; Verify ownership or authorized executor
        (asserts! (is-eq caller (get creator will-data)) ERR_UNAUTHORIZED)

        ;; Ensure will is active and ready for execution
        (asserts! (get is-active will-data) ERR_WILL_NOT_READY)
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)

        ;; Ensure there are beneficiaries and total percentage is 100%
        (asserts! (> (len beneficiary-list) u0) ERR_INVALID_BENEFICIARY)
        (asserts! (is-eq (get-total-percentage will-id) u10000)
            ERR_PERCENTAGE_TOTAL_INVALID
        )

        ;; Distribute to each beneficiary
        (fold distribute-to-beneficiary beneficiary-list {
            will-id: will-id,
            total-amount: total-amount,
        })

        ;; Mark will as executed
        (map-set wills will-id
            (merge will-data {
                is-executed: true,
                execution-block: (some stacks-block-height),
                last-updated: stacks-block-height,
            })
        )

        (ok true)
    )
)

;; ========== TIME LOCK FUNCTIONS ==========

;; Enable time lock for a will
(define-public (enable-time-lock
        (will-id uint)
        (lock-duration uint)
    )
    (let (
            (caller tx-sender)
            (will-data (unwrap! (map-get? wills will-id) ERR_NOT_FOUND))
        )
        ;; Verify ownership
        (asserts! (is-eq caller (get creator will-data)) ERR_UNAUTHORIZED)

        ;; Ensure will is not executed
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)

        ;; Validate lock duration
        (asserts! (>= lock-duration MIN_TIME_LOCK) ERR_INVALID_PERCENTAGE)

        ;; Set time lock
        (map-set will-time-locks will-id {
            is-enabled: true,
            lock-duration: lock-duration,
            unlock-block: (some (+ stacks-block-height lock-duration)),
            created-by: caller,
        })

        ;; Update will timestamp
        (map-set wills will-id
            (merge will-data { last-updated: stacks-block-height })
        )

        (ok true)
    )
)

;; Disable time lock for a will
(define-public (disable-time-lock (will-id uint))
    (let (
            (caller tx-sender)
            (will-data (unwrap! (map-get? wills will-id) ERR_NOT_FOUND))
        )
        ;; Verify ownership
        (asserts! (is-eq caller (get creator will-data)) ERR_UNAUTHORIZED)

        ;; Ensure will is not executed
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)

        ;; Remove time lock
        (map-delete will-time-locks will-id)

        ;; Update will timestamp
        (map-set wills will-id
            (merge will-data { last-updated: stacks-block-height })
        )

        (ok true)
    )
)

;; ========== GUARDIAN FUNCTIONS ==========

;; Add a guardian to a will
(define-public (add-guardian
        (will-id uint)
        (guardian-address principal)
        (guardian-name (optional (string-ascii 64)))
    )
    (let (
            (caller tx-sender)
            (will-data (unwrap! (map-get? wills will-id) ERR_NOT_FOUND))
            (current-guardians (default-to (list) (map-get? will-guardian-list will-id)))
        )
        ;; Verify ownership
        (asserts! (is-eq caller (get creator will-data)) ERR_UNAUTHORIZED)

        ;; Ensure will is not executed
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)

        ;; Check guardian limit
        (asserts! (< (len current-guardians) MAX_GUARDIANS)
            ERR_MAX_BENEFICIARIES_REACHED
        )

        ;; Ensure guardian doesn't already exist
        (asserts!
            (is-none (map-get? guardians {
                will-id: will-id,
                guardian-address: guardian-address,
            }))
            ERR_GUARDIAN_ALREADY_EXISTS
        )

        ;; Add guardian
        (map-set guardians {
            will-id: will-id,
            guardian-address: guardian-address,
        } {
            is-active: true,
            added-at: stacks-block-height,
            guardian-name: guardian-name,
        })

        ;; Update guardian list
        (map-set will-guardian-list will-id
            (unwrap! (as-max-len? (append current-guardians guardian-address) u5)
                ERR_MAX_BENEFICIARIES_REACHED
            ))

        ;; Update will timestamp
        (map-set wills will-id
            (merge will-data { last-updated: stacks-block-height })
        )

        (ok true)
    )
)

;; Remove a guardian from a will
(define-public (remove-guardian
        (will-id uint)
        (guardian-address principal)
    )
    (let (
            (caller tx-sender)
            (will-data (unwrap! (map-get? wills will-id) ERR_NOT_FOUND))
            (guardian-data (unwrap!
                (map-get? guardians {
                    will-id: will-id,
                    guardian-address: guardian-address,
                })
                ERR_NOT_FOUND
            ))
        )
        ;; Verify ownership
        (asserts! (is-eq caller (get creator will-data)) ERR_UNAUTHORIZED)

        ;; Ensure will is not executed
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)

        ;; Remove guardian
        (map-delete guardians {
            will-id: will-id,
            guardian-address: guardian-address,
        })

        ;; Note: For simplicity, we'll rebuild the guardian list when needed
        ;; In a production environment, you'd implement proper list management

        ;; Update will timestamp
        (map-set wills will-id
            (merge will-data { last-updated: stacks-block-height })
        )

        (ok true)
    )
)

;; ========== HEARTBEAT FUNCTIONS ==========

;; Initialize heartbeat for a will
(define-public (enable-heartbeat
        (will-id uint)
        (timeout-duration uint)
    )
    (let (
            (caller tx-sender)
            (will-data (unwrap! (map-get? wills will-id) ERR_NOT_FOUND))
        )
        ;; Verify ownership
        (asserts! (is-eq caller (get creator will-data)) ERR_UNAUTHORIZED)

        ;; Ensure will is not executed
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)

        ;; Validate timeout duration (minimum 30 days)
        (asserts! (>= timeout-duration MIN_TIME_LOCK) ERR_INVALID_PERCENTAGE)

        ;; Set heartbeat
        (map-set will-heartbeats will-id {
            last-heartbeat: stacks-block-height,
            is-active: true,
            timeout-duration: timeout-duration,
        })

        ;; Update will timestamp
        (map-set wills will-id
            (merge will-data { last-updated: stacks-block-height })
        )

        (ok true)
    )
)

;; Send heartbeat signal
(define-public (send-heartbeat (will-id uint))
    (let (
            (caller tx-sender)
            (will-data (unwrap! (map-get? wills will-id) ERR_NOT_FOUND))
            (heartbeat-data (unwrap! (map-get? will-heartbeats will-id) ERR_NOT_FOUND))
        )
        ;; Verify ownership
        (asserts! (is-eq caller (get creator will-data)) ERR_UNAUTHORIZED)

        ;; Ensure will is not executed
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)

        ;; Ensure heartbeat is active
        (asserts! (get is-active heartbeat-data) ERR_WILL_NOT_READY)

        ;; Update heartbeat
        (map-set will-heartbeats will-id
            (merge heartbeat-data { last-heartbeat: stacks-block-height })
        )

        ;; Update will timestamp
        (map-set wills will-id
            (merge will-data { last-updated: stacks-block-height })
        )

        (ok true)
    )
)

;; ========== EMERGENCY EXECUTION FUNCTIONS ==========

;; Request emergency execution (by guardians)
(define-public (request-emergency-execution (will-id uint))
    (let (
            (caller tx-sender)
            (will-data (unwrap! (map-get? wills will-id) ERR_NOT_FOUND))
            (guardian-data (unwrap!
                (map-get? guardians {
                    will-id: will-id,
                    guardian-address: caller,
                })
                ERR_NOT_GUARDIAN
            ))
            (guardian-list (default-to (list) (map-get? will-guardian-list will-id)))
            (required-approvals (/ (len guardian-list) u2)) ;; Majority approval
        )
        ;; Ensure will is not executed
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)

        ;; Ensure caller is an active guardian
        (asserts! (get is-active guardian-data) ERR_NOT_GUARDIAN)

        ;; Check if heartbeat has expired (if enabled)
        (match (map-get? will-heartbeats will-id)
            heartbeat-data
            (let ((timeout-block (+ (get last-heartbeat heartbeat-data)
                    (get timeout-duration heartbeat-data)
                )))
                (asserts! (>= stacks-block-height timeout-block)
                    ERR_HEARTBEAT_EXPIRED
                )
            )
            true ;; No heartbeat enabled, proceed
        )

        ;; Create emergency execution request
        (map-set emergency-executions will-id {
            requested-by: caller,
            requested-at: stacks-block-height,
            guardian-approvals: u1, ;; Requester auto-approves
            required-approvals: (if (> required-approvals u0)
                required-approvals
                u1
            ),
            is-approved: false,
        })

        (ok true)
    )
)

;; Approve emergency execution (by other guardians)
(define-public (approve-emergency-execution (will-id uint))
    (let (
            (caller tx-sender)
            (will-data (unwrap! (map-get? wills will-id) ERR_NOT_FOUND))
            (guardian-data (unwrap!
                (map-get? guardians {
                    will-id: will-id,
                    guardian-address: caller,
                })
                ERR_NOT_GUARDIAN
            ))
            (emergency-data (unwrap! (map-get? emergency-executions will-id) ERR_NOT_FOUND))
        )
        ;; Ensure will is not executed
        (asserts! (not (get is-executed will-data)) ERR_WILL_ALREADY_EXECUTED)

        ;; Ensure caller is an active guardian
        (asserts! (get is-active guardian-data) ERR_NOT_GUARDIAN)

        ;; Ensure emergency execution is not already approved
        (asserts! (not (get is-approved emergency-data)) ERR_EXECUTION_BLOCKED)

        ;; Increment approvals
        (let ((new-approvals (+ (get guardian-approvals emergency-data) u1)))
            (map-set emergency-executions will-id
                (merge emergency-data {
                    guardian-approvals: new-approvals,
                    is-approved: (>= new-approvals (get required-approvals emergency-data)),
                })
            )
        )

        (ok true)
    )
)

;; Execute will through emergency process
(define-public (emergency-execute-will (will-id uint))
    (let (
            (caller tx-sender)
            (will-data (unwrap! (map-get? wills will-id) ERR_NOT_FOUND))
            (emergency-data (unwrap! (map-get? emergency-executions will-id) ERR_NOT_FOUND))
            (guardian-data (unwrap!
                (map-get? guardians {
                    will-id: will-id,
                    guardian-address: caller,
                })
                ERR_NOT_GUARDIAN
            ))
        )
        ;; Ensure caller is an active guardian
        (asserts! (get is-active guardian-data) ERR_NOT_GUARDIAN)

        ;; Ensure emergency execution is approved
        (asserts! (get is-approved emergency-data) ERR_EXECUTION_BLOCKED)

        ;; Check time lock if enabled
        (match (map-get? will-time-locks will-id)
            time-lock-data
            (if (get is-enabled time-lock-data)
                (match (get unlock-block time-lock-data)
                    unlock-block (asserts! (>= stacks-block-height unlock-block)
                        ERR_TIME_LOCK_ACTIVE
                    )
                    true
                )
                true
            )
            true ;; No time lock
        )

        ;; Execute the distribution (reuse existing distribute-assets logic)
        (try! (distribute-assets will-id))

        ;; Clean up emergency execution data
        (map-delete emergency-executions will-id)

        (ok true)
    )
)

;; read only functions

;; Get will details by ID
(define-read-only (get-will-details (will-id uint))
    (map-get? wills will-id)
)

;; Get will ID for a user
(define-read-only (get-user-will-id (user principal))
    (map-get? user-will user)
)

;; Get will owner by will ID
(define-read-only (get-will-owner (will-id uint))
    (map-get? will-owners will-id)
)

;; Get next available will ID
(define-read-only (get-next-will-id)
    (var-get next-will-id)
)

;; Get contract fee
(define-read-only (get-contract-fee)
    (var-get contract-fee)
)

;; Check if user has a will
(define-read-only (has-will (user principal))
    (is-some (map-get? user-will user))
)

;; Get will status
(define-read-only (get-will-status (will-id uint))
    (match (map-get? wills will-id)
        will-data (ok {
            is-active: (get is-active will-data),
            is-executed: (get is-executed will-data),
            beneficiary-count: (get beneficiary-count will-data),
            total-stx-amount: (get total-stx-amount will-data),
        })
        ERR_NOT_FOUND
    )
)

;; Get beneficiary details
(define-read-only (get-beneficiary-details
        (will-id uint)
        (beneficiary-address principal)
    )
    (map-get? beneficiaries {
        will-id: will-id,
        beneficiary-address: beneficiary-address,
    })
)

;; Get all beneficiaries for a will
(define-read-only (get-will-beneficiaries (will-id uint))
    (map-get? will-beneficiary-list will-id)
)

;; Calculate total percentage allocated
(define-read-only (get-total-percentage (will-id uint))
    (match (map-get? will-beneficiary-list will-id)
        beneficiary-list (get total
            (fold sum-beneficiary-percentage beneficiary-list {
                will-id: will-id,
                total: u0,
            })
        )
        u0
    )
)

;; Get beneficiary allocation amount in STX
(define-read-only (get-beneficiary-allocation
        (will-id uint)
        (beneficiary-address principal)
    )
    (match (map-get? wills will-id)
        will-data (match (map-get? beneficiaries {
            will-id: will-id,
            beneficiary-address: beneficiary-address,
        })
            beneficiary-data (let (
                    (total-amount (get total-stx-amount will-data))
                    (percentage (get percentage beneficiary-data))
                )
                (ok (/ (* total-amount percentage) u10000))
            )
            ERR_NOT_FOUND
        )
        ERR_NOT_FOUND
    )
)

;; ========== ADVANCED READ-ONLY FUNCTIONS ==========

;; Get time lock details
(define-read-only (get-time-lock-details (will-id uint))
    (map-get? will-time-locks will-id)
)

;; Check if time lock is active
(define-read-only (is-time-lock-active (will-id uint))
    (match (map-get? will-time-locks will-id)
        time-lock-data (if (get is-enabled time-lock-data)
            (match (get unlock-block time-lock-data)
                unlock-block (< stacks-block-height unlock-block)
                false
            )
            false
        )
        false
    )
)

;; Get guardian details
(define-read-only (get-guardian-details
        (will-id uint)
        (guardian-address principal)
    )
    (map-get? guardians {
        will-id: will-id,
        guardian-address: guardian-address,
    })
)

;; Get all guardians for a will
(define-read-only (get-will-guardians (will-id uint))
    (map-get? will-guardian-list will-id)
)

;; Get heartbeat status
(define-read-only (get-heartbeat-status (will-id uint))
    (match (map-get? will-heartbeats will-id)
        heartbeat-data (let ((timeout-block (+ (get last-heartbeat heartbeat-data)
                (get timeout-duration heartbeat-data)
            )))
            (ok {
                last-heartbeat: (get last-heartbeat heartbeat-data),
                is-active: (get is-active heartbeat-data),
                timeout-duration: (get timeout-duration heartbeat-data),
                is-expired: (>= stacks-block-height timeout-block),
                blocks-until-timeout: (if (>= stacks-block-height timeout-block)
                    u0
                    (- timeout-block stacks-block-height)
                ),
            })
        )
        ERR_NOT_FOUND
    )
)

;; Get emergency execution status
(define-read-only (get-emergency-execution-status (will-id uint))
    (map-get? emergency-executions will-id)
)

;; Check if will is ready for execution
(define-read-only (is-will-ready-for-execution (will-id uint))
    (match (map-get? wills will-id)
        will-data (let ((basic-checks (and
                (get is-active will-data)
                (not (get is-executed will-data))
                (> (get beneficiary-count will-data) u0)
                (is-eq (get-total-percentage will-id) u10000)
            )))
            (if basic-checks
                ;; Check time lock if enabled
                (match (map-get? will-time-locks will-id)
                    time-lock-data
                    (if (get is-enabled time-lock-data)
                        (match (get unlock-block time-lock-data)
                            unlock-block (>= stacks-block-height unlock-block)
                            true
                        )
                        true
                    )
                    true ;; No time lock
                )
                false
            )
        )
        false
    )
)

;; Get comprehensive will summary
(define-read-only (get-will-summary (will-id uint))
    (match (map-get? wills will-id)
        will-data (ok {
            will-details: will-data,
            beneficiary-count: (get beneficiary-count will-data),
            total-percentage: (get-total-percentage will-id),
            time-lock-active: (is-time-lock-active will-id),
            ready-for-execution: (is-will-ready-for-execution will-id),
            guardian-count: (len (default-to (list) (map-get? will-guardian-list will-id))),
            has-heartbeat: (is-some (map-get? will-heartbeats will-id)),
            has-emergency-request: (is-some (map-get? emergency-executions will-id)),
        })
        ERR_NOT_FOUND
    )
)

;; private functions

;; Verify will ownership (internal helper)
(define-private (verify-will-ownership
        (will-id uint)
        (caller principal)
    )
    (match (map-get? will-owners will-id)
        owner (is-eq owner caller)
        false
    )
)

;; Helper function to sum beneficiary percentages
(define-private (sum-beneficiary-percentage
        (beneficiary-address principal)
        (acc {
            will-id: uint,
            total: uint,
        })
    )
    (let (
            (will-id (get will-id acc))
            (current-total (get total acc))
        )
        (match (map-get? beneficiaries {
            will-id: will-id,
            beneficiary-address: beneficiary-address,
        })
            beneficiary-data (merge acc { total: (+ current-total (get percentage beneficiary-data)) })
            acc
        )
    )
)

;; Helper function to distribute to a single beneficiary
(define-private (distribute-to-beneficiary
        (beneficiary-address principal)
        (context {
            will-id: uint,
            total-amount: uint,
        })
    )
    (let (
            (will-id (get will-id context))
            (total-amount (get total-amount context))
        )
        (match (map-get? beneficiaries {
            will-id: will-id,
            beneficiary-address: beneficiary-address,
        })
            beneficiary-data
            (let (
                    (percentage (get percentage beneficiary-data))
                    (amount (/ (* total-amount percentage) u10000))
                )
                (begin
                    (and
                        (> amount u0)
                        (is-ok (as-contract (stx-transfer? amount tx-sender beneficiary-address)))
                    )
                    context ;; Return the context for fold
                )
            )
            context ;; Return the context for fold
        )
    )
)

