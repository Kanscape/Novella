import ExpoModulesCore
import UIKit

struct SegmentedControlOption: Record {
  @Field var label: String = ""
  @Field var value: String = ""
}

final class NovellaSegmentedControlView: ExpoView {
  private let segmentedControl = UISegmentedControl(frame: .zero)

  let onValueChange = EventDispatcher()

  private var optionValues: [String] = []
  private var selectedValue = ""

  required init(appContext: AppContext? = nil) {
    super.init(appContext: appContext)

    segmentedControl.translatesAutoresizingMaskIntoConstraints = false
    segmentedControl.addTarget(self, action: #selector(handleValueChanged), for: .valueChanged)
    addSubview(segmentedControl)

    // The React layout system sizes this view (see the native-segmented-control
    // wrappers); the native control keeps its default height and is centered
    // vertically inside the frame. Never constrain the ExpoView itself:
    // installing Auto Layout constraints on the RN-managed view breaks its
    // Yoga frame and it escapes the page layout.
    NSLayoutConstraint.activate([
      segmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor),
      segmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor),
      segmentedControl.centerYAnchor.constraint(equalTo: centerYAnchor)
    ])
  }

  func setOptions(_ options: [SegmentedControlOption]) {
    optionValues = options.map(\.value)
    segmentedControl.removeAllSegments()
    for (index, option) in options.enumerated() {
      segmentedControl.insertSegment(withTitle: option.label, at: index, animated: false)
    }
    segmentedControl.selectedSegmentIndex = optionValues.firstIndex(of: selectedValue) ?? -1
  }

  func setSelectedValue(_ selectedValue: String) {
    self.selectedValue = selectedValue
    segmentedControl.selectedSegmentIndex = optionValues.firstIndex(of: selectedValue) ?? -1
  }

  func setEnabled(_ enabled: Bool) {
    segmentedControl.isEnabled = enabled
  }

  @objc
  private func handleValueChanged() {
    let index = segmentedControl.selectedSegmentIndex
    guard index >= 0, index < optionValues.count else { return }
    onValueChange(["value": optionValues[index]])
  }
}
