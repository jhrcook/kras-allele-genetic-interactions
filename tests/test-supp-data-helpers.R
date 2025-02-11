# Tests for the Supp. Data API.

test_that("The sheet names are properly cleaned.", {
  expect_equal(clean_sheet_name("some name word"), "some-name-word")
  expect_equal(clean_sheet_name("some_name_word"), "some-name-word")
  expect_equal(clean_sheet_name("some_name word"), "some-name-word")
  expect_equal(clean_sheet_name("some_name word 2"), "some-name-word-2")
  expect_equal(
    clean_sheet_name("some_name weird 2@ % , __,   "),
    "some-name-weird-2@-%-,---,---"
  )
  expect_equal(clean_sheet_name("   "), "---")
  expect_equal(clean_sheet_name(" __ "), "----")
  expect_equal(clean_sheet_name(" _._ "), "--.--")
})


test_that("The file name conforms to the correct template.", {
  expect_equal(
    supp_data_filename(1, "some name here"),
    "001_some-name-here.txt"
  )
  expect_equal(
    supp_data_filename("1", "some name here"),
    "001_some-name-here.txt"
  )
  expect_equal(
    supp_data_filename("101", "some name here"),
    "101_some-name-here.txt"
  )

  expect_error(supp_data_filename(1000, "some name here"), "too long")
  expect_error(supp_data_filename(1, "s"), "too short")
})


test_that("A test data frame is correctly written.", {
  df <- data.frame(a = c(1, 2, 3, 4), b = letters[1:4])

  expected_path <- here::here(
    SUPP_DATA_SHEETS_DIR,
    "999_test-data-frame.txt"
  )

  out_df <- expect_invisible(
    save_supp_data(df, 999, "test data frame")
  )
  expect_equal(df, out_df)

  # Clean up.
  if (file.exists(expected_path)) file.remove(expected_path)
})


test_that("The sheet path is turned into a sheet name.", {
  expect_error(prep_sheet_name("some name here"))
  expect_equal(prep_sheet_name("101_some-name-here.txt"), "some name here")
  expect_equal(
    prep_sheet_name("some/file/path/101_some-name-here.txt"),
    "some name here"
  )
  expect_equal(
    prep_sheet_name("101_some-!@@!,.-here.txt"),
    "some !@@!,. here"
  )
})
