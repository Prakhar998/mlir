// RUN: mlir-opt %s -affine-loop-unroll-jam -unroll-jam-factor=2 | FileCheck %s

// CHECK-DAG: [[MAP_PLUS_1:#map[0-9]+]] = (d0) -> (d0 + 1)
// CHECK-DAG: [[M1:#map[0-9]+]] = ()[s0] -> (s0 + 8)
// CHECK-DAG: [[MAP_DIV_OFFSET:#map[0-9]+]] = ()[s0] -> (((s0 - 1) floordiv 2) * 2 + 1)
// CHECK-DAG: [[MAP_MULTI_RES:#map[0-9]+]] = ()[s0, s1] -> ((s0 floordiv 2) * 2, (s1 floordiv 2) * 2, 1024)

// CHECK-LABEL: func @unroll_jam_imperfect_nest() {
func @unroll_jam_imperfect_nest() {
  // CHECK: %c100 = constant 100 : index
  // CHECK-NEXT: affine.for %arg0 = 0 to 100 step 2 {
  affine.for %i = 0 to 101 {
    // CHECK: "addi32"(%arg0, %arg0) : (index, index) -> i32
    // CHECK-NEXT: %3 = affine.apply [[MAP_PLUS_1]](%arg0)
    // CHECK-NEXT: "addi32"(%3, %3) : (index, index) -> i32
    %x = "addi32"(%i, %i) : (index, index) -> i32
    affine.for %j = 0 to 17 {
      // CHECK:      %8 = "addi32"(%arg0, %arg0) : (index, index) -> i32
      // CHECK-NEXT: "addi32"(%8, %8) : (i32, i32) -> i32
      // CHECK-NEXT: %10 = affine.apply [[MAP_PLUS_1]](%arg0)
      // CHECK-NEXT: %11 = "addi32"(%10, %10) : (index, index) -> i32
      // CHECK-NEXT: "addi32"(%11, %11) : (i32, i32) -> i32
      %y = "addi32"(%i, %i) : (index, index) -> i32
      %z = "addi32"(%y, %y) : (i32, i32) -> i32
    }
    // CHECK: "addi32"(%arg0, %arg0) : (index, index) -> i32
    // CHECK-NEXT: %6 = affine.apply [[MAP_PLUS_1]](%arg0)
    // CHECK-NEXT: "addi32"(%6, %6) : (index, index) -> i32
    %w = "addi32"(%i, %i) : (index, index) -> i32
  } // CHECK }
  // cleanup loop (single iteration)
  // CHECK: "addi32"(%c100, %c100) : (index, index) -> i32
  // CHECK-NEXT: affine.for %arg0 = 0 to 17 {
  // CHECK-NEXT:   %2 = "addi32"(%c100, %c100) : (index, index) -> i32
  // CHECK-NEXT:   "addi32"(%2, %2) : (i32, i32) -> i32
  // CHECK-NEXT: }
  // CHECK-NEXT: "addi32"(%c100, %c100) : (index, index) -> i32
  return
}

// CHECK-LABEL: func @loop_nest_unknown_count_1(%arg0: index) {
func @loop_nest_unknown_count_1(%N : index) {
  // CHECK-NEXT: affine.for %arg1 = 1 to [[MAP_DIV_OFFSET]]()[%arg0] step 2 {
  // CHECK-NEXT:   affine.for %arg2 = 1 to 100 {
  // CHECK-NEXT:     %0 = "foo"() : () -> i32
  // CHECK-NEXT:     %1 = "foo"() : () -> i32
  // CHECK-NEXT:   }
  // CHECK-NEXT: }
  // A cleanup loop should be generated here.
  // CHECK-NEXT: affine.for %arg1 = [[MAP_DIV_OFFSET]]()[%arg0] to %arg0 {
  // CHECK-NEXT:   affine.for %arg2 = 1 to 100 {
  // CHECK-NEXT:     "foo"() : () -> i32
  // CHECK_NEXT:   }
  // CHECK_NEXT: }
  affine.for %i = 1 to %N {
    affine.for %j = 1 to 100 {
      %x = "foo"() : () -> i32
    }
  }
  return
}

// CHECK-LABEL: func @loop_nest_unknown_count_2(%arg0: index) {
func @loop_nest_unknown_count_2(%arg : index) {
  // CHECK-NEXT: affine.for %arg1 = %arg0 to  [[M1]]()[%arg0] step 2 {
  // CHECK-NEXT:   affine.for %arg2 = 1 to 100 {
  // CHECK-NEXT:     "foo"(%arg1) : (index) -> i32
  // CHECK-NEXT:     %2 = affine.apply #map{{[0-9]+}}(%arg1)
  // CHECK-NEXT:     "foo"(%2) : (index) -> i32
  // CHECK-NEXT:   }
  // CHECK-NEXT: }
  // The cleanup loop is a single iteration one and is promoted.
  // CHECK-NEXT: %0 = affine.apply [[M1]]()[%arg0]
  // CHECK-NEXT: affine.for %arg1 = 1 to 100 {
  // CHECK-NEXT:   "foo"(%0) : (index) -> i32
  // CHECK_NEXT: }
  affine.for %i = %arg to ()[s0] -> (s0+9) ()[%arg] {
    affine.for %j = 1 to 100 {
      %x = "foo"(%i) : (index) -> i32
    }
  }
  return
}

// CHECK-LABEL: func @loop_nest_symbolic_and_min_upper_bound
func @loop_nest_symbolic_and_min_upper_bound(%M : index, %N : index, %K : index) {
  affine.for %i = 0 to min ()[s0, s1] -> (s0, s1, 1024)()[%M, %N] {
    affine.for %j = 0 to %K {
      "foo"(%i, %j) : (index, index) -> ()
    }
  }
  return
}
// CHECK-NEXT:  affine.for %arg3 = 0 to min [[MAP_MULTI_RES]]()[%arg0, %arg1] step 2 {
// CHECK-NEXT:    affine.for %arg4 = 0 to %arg2 {
// CHECK-NEXT:      "foo"(%arg3, %arg4) : (index, index) -> ()
// CHECK-NEXT:      %0 = affine.apply #map0(%arg3)
// CHECK-NEXT:      "foo"(%0, %arg4) : (index, index) -> ()
// CHECK-NEXT:    }
// CHECK-NEXT:  }
// CHECK-NEXT:  affine.for %arg3 = max [[MAP_MULTI_RES]]()[%arg0, %arg1] to min #map9()[%arg0, %arg1] {
// CHECK-NEXT:    affine.for %arg4 = 0 to %arg2 {
// CHECK-NEXT:      "foo"(%arg3, %arg4) : (index, index) -> ()
// CHECK-NEXT:    }
// CHECK-NEXT:  }
// CHECK-NEXT:  return
