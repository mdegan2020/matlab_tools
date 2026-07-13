# C0 Notation and Equation Inventory

Status: frozen reference baseline for the C1 manuscript, C2 procedural oracle,
C3 appendices, golden parity, and staged C++ translation. This inventory fixes
meaning and composition order; it does not freeze a particular implementation.

## Authoritative conventions

- World points and vectors are 3-by-1 columns. A collection is 3-by-N.
- Full-source image observations are `[column,row]`; arrays remain indexed
  `(row,column)`.
- Frames are right-handed. A rotation `R_ab` maps coordinates from frame `b`
  into frame `a`: `x_a = R_ab x_b`.
- A homogeneous transform `T_ab=[R_ab,t_ab;0,1]` maps points from `b` to `a`.
- Active local attitude increments left-compose nominal attitude:
  `R_new = Exp([delta_theta]_x) R_nominal`.
- Authoritative angles are radians and angular covariance is radians squared.
- Plane basis columns are `[e_x,e_y]` with `cross(e_x,e_y)=n`.
- Physical geometry, plane-basis reparameterization, and presentation-only
  transforms are separate categories and must never be silently substituted.
- Scientific geometry, solvers, covariance, backend mapping, and the procedural
  oracle use double precision. Any single/mixed path has a named boundary and a
  double reference comparison.

## Frames

| Symbol | Frame | Origin and axes | Units |
| --- | --- | --- | --- |
| `W` | World/project | Stable project origin; right-handed Cartesian axes | m |
| `E` | Local ENU | DEM/reference origin; east, north, up | m |
| `B(t)` | Platform/body | Time-dependent platform origin and body axes | m, rad |
| `G_r(t)` | Roll gimbal | Body followed by roll-gimbal rotation | rad |
| `G_p(t)` | Pitch gimbal | Roll gimbal followed by pitch-gimbal rotation | rad |
| `S(t,c)` | Scanner/ray | Final scanner look direction at time/column | rad |
| `I_i` | Full source image | Columns right, rows down; continuous coordinates | px |
| `Pi` | Physical plane | Origin `p_0`, basis `[e_x,e_y]`, normal `n` | m |
| `C` | Presentation camera | Position, view direction, up, and right | m |
| `D` | Display/anaglyph | Output rows/columns and color channels | px |

## Core symbols

| Symbol | Meaning |
| --- | --- |
| `p,g,v,n` | World point, ray origin, ray vector, unit plane normal |
| `q=[x,y]^T` | Physical-plane coordinate |
| `u=[c,r]^T` | Continuous full-source image coordinate |
| `R_ab,t_ab,T_ab` | Rotation, translation, homogeneous transform from `b` to `a` |
| `[a]_x` | Skew matrix satisfying `[a]_x b = a cross b` |
| `theta=(omega,phi,kappa)` | OPK correction under the declared active convention |
| `delta_theta` | Small local tangent rotation vector |
| `b_ij` | Baseline from view `i` to view `j` |
| `rho` | Robust loss; `w` is its induced weight |
| `Sigma` | Covariance in the frame and units stated by its subscript |
| `B_k(c),q_ik` | Cubic B-spline basis and view-control rotation vector |
| `d` | Disparity or local search displacement |
| `lambda_i` | Forward range along ray `i` |
| `H,J,N` | Hessian approximation, Jacobian, and weighted normal matrix |

## Frozen equation inventory

The equation IDs below are stable cross-reference keys. The manuscript carries
their derivation and the C2 tests exercise the procedural subset.

### Frames, sensor formation, planes, and rays

| ID | Frozen relation or invariant | Verification boundary |
| --- | --- | --- |
| `EQ-FRM-01` | `p_a = R_ab p_b + t_ab` | Transform composition and inverse round trip |
| `EQ-FRM-02` | `T_ac = T_ab T_bc` | Ordered frame-chain parity |
| `EQ-ROT-01` | `Exp([d]_x)=I+(sin a/a)[d]_x+((1-cos a)/a^2)[d]_x^2` | Proper rotation; small-angle limit |
| `EQ-SEN-01` | `R_WI(t,c)=R_WB(t) R_BG_r(t) R_G_rG_p(t) R_G_pS(t,c) R_SI` | Platform-roll-pitch-scanner order |
| `EQ-SEN-02` | `g(t,c)=p_WB(t)+R_WB(t) l_B` | Lever-arm origin formation |
| `EQ-SEN-03` | `v_W(t,c,r)=R_WI(t,c) K^{-1}[c,r,1]^T / ||.||` | Full-source ray formation |
| `EQ-PLN-01` | `Pi={p:p=p_0+e_x x+e_y y}`, `E=[e_x,e_y]`, `E^T E=I` | Basis/normal handedness |
| `EQ-PLN-02` | `q=E^T(p-p_0)`, `p=p_0+E q` | Plane/world round trip |
| `EQ-RAY-01` | `lambda=n^T(p_0-g)/(n^T v)`, `p=g+lambda v` | Parallel and behind-origin rejection |
| `EQ-TER-01` | `p=g+lambda v`, `h(p)=0` | Terrain intersection convergence/void state |

### Full-source projection and sparse evidence

| ID | Frozen relation or invariant | Verification boundary |
| --- | --- | --- |
| `EQ-INV-01` | `u_i(q)=Interp_scattered({q_ik}->{u_ik},q)` | Mesh-vertex identity and continuous inverse map |
| `EQ-IMG-01` | `I_i^Pi(q)=Interp_image(I_i,u_i(q))` | Bilinear/nearest value and mask parity |
| `EQ-MSK-01` | `m_i(q)=m_geom m_image m_operator` | Invalid values never become evidence |
| `EQ-MAT-01` | `e_desc=||f_i-f_j||`, with ratio/tie/uniqueness evidence | Deterministic feature matching |
| `EQ-EPI-01` | `e_ij=(v_i x v_j)^T b_ij / max(||b_ij||,eps)` | Baseline-scale-invariant coplanarity |
| `EQ-CON-01` | `min_z sum_k rho(||A_k z-y_k||_Sigma)` | Consensus model with explicit inlier state |
| `EQ-TRK-01` | A track contains at most one observation per stable view | Conflict/path/cycle tests |

### Global alignment and time-varying research

| ID | Frozen relation or invariant | Verification boundary |
| --- | --- | --- |
| `EQ-NET-01` | `min_delta sum_m rho(r_m(delta)/sigma_m)+||L(delta-mu)||^2` | Robust objective and prior separation |
| `EQ-NET-02` | `delta_theta_i=delta_theta_pass(i)+epsilon_i` | Pass-common/per-image reporting |
| `EQ-NET-03` | `sum_i Lambda_i epsilon_i=0` within each pass | Prior-weighted balanced gauge |
| `EQ-NET-04` | `N=J^T W J+L^T L`, `Sigma_delta=N^dagger` when observable | Rank, conditioning, covariance status |
| `EQ-TVC-01` | `delta_theta_i(c)=delta_theta_p+B_i(c)q_i` | Pass-common tangent cubic spline |
| `EQ-TVC-02` | `R_i(c)=Exp([delta_theta_i(c)]_x)R_i^0(c)` | No Euler interpolation |
| `EQ-TVC-03` | `||D_2 q_i||^2` plus balanced differential gauge | Smoothness/prior dominance |
| `EQ-TVC-04` | Double post spacing until support, rank, and condition pass | Automatic coarsening/fail closed |

### Pair camera, physical eyes, and presentation-only stereo

| ID | Frozen relation or invariant | Verification boundary |
| --- | --- | --- |
| `EQ-CAM-01` | Pair camera aims from a midpoint-derived position to common footprint centroid | Camera-only change |
| `EQ-EYE-01` | `s_i=r_C^T g_i`; left eye is smaller `s_i` outside hysteresis | Layer-order-invariant assignment |
| `EQ-EYE-02` | Retain prior eyes while signed normalized separation is above `-h` | Head-on hysteresis |
| `EQ-DSP-01` | `Delta=(eta-1) beta W_C+d_0` | Separation/depth scalar |
| `EQ-DSP-02` | `o_left=-Delta r_C`, `o_right=+Delta r_C` | Exact display-only offsets |
| `EQ-DSP-03` | Display sampling uses `q_i^D=q-E^T o_i`; physical `q,p,Pi` stay fixed | Procedural/production parity |
| `EQ-ANA-01` | `A=[Y_left,Y_right,Y_right]` on common valid support | Canonical red/cyan composition |

### Dense correspondence, reconstruction, uncertainty, and surfaces

| ID | Frozen relation or invariant | Verification boundary |
| --- | --- | --- |
| `EQ-DEN-01` | `C_ZNCC=1-cov(a,b)/(sigma_a sigma_b)` | Texture/constant-patch state |
| `EQ-DEN-02` | `C_grad`, census/rank Hamming cost, and phase-only cost are explicit alternatives | Cost-specific deterministic tests |
| `EQ-DEN-03` | `d*=d_0+(C_- - C_+)/(2(C_- -2C_0+C_+))` | Bounded subpixel parabola |
| `EQ-DEN-04` | `||u_L-FB(u_L)||<=tau_FB` | Occlusion/consistency state |
| `EQ-TRI-01` | `min_p sum_i w_i||(I-v_i v_i^T)(p-g_i)||^2` | Pair and multi-ray recovery |
| `EQ-TRI-02` | Forward ranges, ray angle, normal rank, and residual determine reliability | Degeneracy classification |
| `EQ-COV-01` | `Sigma_p=J_u Sigma_u J_u^T+J_g Sigma_g J_g^T` | Frame/unit/correlation propagation |
| `EQ-FUS-01` | Unique view/pass evidence is counted once; pair multiplicity adds no information | Multi-view association/fusion |
| `EQ-SUR-01` | Surface estimators retain competing modes and provenance | Point/voxel/mesh/grid product tests |
| `EQ-DEM-01` | `min_t sum_k rho((n_k^T(p_k+t-d_k))/sigma_k)` | Robust point-to-normal translation |
| `EQ-DEM-02` | `Sigma_t=(J^T W J+Sigma_prior^-1)^dagger` plus shared DEM floor | Ambiguity/covariance evidence |

### Precision and acceptance

| ID | Frozen relation or invariant | Verification boundary |
| --- | --- | --- |
| `EQ-PRE-01` | Subtract a double render origin before an explicit discardable single cast | 100 km and horizon-limited stretch matrix |
| `EQ-PRE-02` | Scale-aware tolerances combine absolute, relative, angular, and pixel terms | Cross-platform golden comparison |
| `EQ-PRE-03` | Cancellation/progress state cannot alter deterministic completed values | SDK and future C++ parity |

## Required degeneracy states

Parallel/behind-origin rays, duplicate or missing stable identities, empty masks,
zero texture, repeated texture ties, disconnected or ungauged networks, rank or
condition failure, bound hits, prior-dominated estimates, near-parallel
triangulation, competing depth modes, DEM void/datum ambiguity, and unavailable
covariance are named states. They are never represented as a plausible numeric
answer with no diagnostic.

## C2/C++ golden payload

The public golden payload contains small generated arrays and geometry only. It
records output-grid plane/world coordinates, continuous source row/column maps,
per-eye values and masks, physical eye identity, display-only offsets, canonical
red/cyan output, precision, and tolerances. Private fixture configuration and
runtime handles are excluded from persisted output.
