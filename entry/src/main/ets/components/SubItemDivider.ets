@Preview
@ComponentV2
export struct SubItemDivider {
  build() {
    Divider().vertical(false)
      .padding({ left: 10, right: 10, top: 0, bottom: 0})
  }
}