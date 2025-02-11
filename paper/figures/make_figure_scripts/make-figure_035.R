# Figure 035. Final figure looking at the integration of the comutation and
# genetic dependency results.

FIGNUM <- 35

# > SET THE FIGURE DIMENSIONS
FIG_DIMENSIONS <- get_figure_dimensions(2, "medium")

library(flextable)


theme_fig35 <- function(tag_margin = margin(1, 1, 1, 1, "mm")) {
  theme_comutation() %+replace%
    theme(
      plot.tag = element_text(
        size = 7,
        face = "bold",
        margin = tag_margin
      )
    )
}

theme_minimal_fig35 <- function(tag_margin = margin(1, 1, 1, 1, "mm")) {
  theme_minimal_comutation() %+replace%
    theme(
      plot.tag = element_text(
        size = 7,
        face = "bold",
        margin = tag_margin
      )
    )
}


#' Special theme for graphs from 'ggraph'.
theme_graph_fig35 <- function(tag_margin = margin(0, 0, 0, 0, "mm")) {
  theme_graph(base_size = 7, base_family = "Arial") %+replace%
    theme(
      plot.title = element_blank(),
      plot.tag = element_text(
        size = 7,
        face = "bold",
        margin = tag_margin
      ),
      legend.margin = margin(0, 0, 0, 0, "mm"),
      legend.position = "right",
      legend.title = element_text(size = 5, hjust = 0.5),
      legend.text = element_text(size = 5, hjust = 0.5),
      plot.margin = margin(0, 0, 0, 0, "mm")
    )
}


#### ---- A. Table of comutation and dep. overlaps ---- ####
# A table of the genes found to comutate and show differential dependency
# with an allele.
# original script: "src/40_12_overlap-synlet-comutation-hits.R"

panel_A <- patchwork::plot_spacer()



#### ---- B. Connectivity of hits ---- ####
# Bar plots of the overall connectivity of hits on the PPI.
# original script: "src/40_20_comut-dependency-genes-ppi-connectivity.R"

panel_B <- read_fig_proto("comut_dep_connectivity_bars") +
  facet_wrap(. ~ cancer, scales = "free_x", nrow = 1) +
  scale_fill_viridis_d(
    option = "magma", begin = 0.2, end = 1,
    guide = guide_legend(
      nrow = 1,
      title.theme = element_text(
        size = 6, hjust = 0,
        face = "bold", vjust = 0.25
      ),
      title.position = "left",
      label.theme = element_text(size = 6, hjust = 0.5),
      label.position = "top"
    )
  ) +
  theme_fig35() +
  theme(
    axis.title.x = element_blank(),
    axis.text.x = element_text(angle = 30, hjust = 1),
    legend.key.size = unit(4, "mm"),
    legend.position = "bottom",
    strip.text = element_text(size = 7, face = "bold")
  ) +
  labs(
    tag = "b",
    y = "fraction of geodesic distances"
  )


#### ---- D. Comparing PPI subnets in COAD ---- ####
# A subnetwork of the PPIN for COAD showing the comut. and dep. results for
# all alleles.
# original script: "src/40_15_comparing-COAD-allele-subnetworks.R"

panel_C <- read_fig_proto("coad_overlap_comparison_plot.rds") +
  theme_graph_fig35(margin(5, 0, 0, 0, "mm")) +
  theme(
    legend.position = c(0.90, 0.08),
    legend.title = element_blank(),
    legend.text = element_text(size = 6)
  ) +
  labs(
    color = "allele",
    tag = "c"
  )


#### ---- Figure assembly ---- ####

{
  set.seed(0)
  # COMPLETE FIGURE
  full_figure <- (
    ((panel_A | panel_B) + plot_layout(widths = c(1, 1))) /
      panel_C
  ) +
    plot_layout(heights = c(1, 4))

  save_figure(
    full_figure,
    figure_num = FIGNUM,
    dim = FIG_DIMENSIONS
  )
}
