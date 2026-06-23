import { FormExtensionAbility, formBindingData } from '@kit.FormKit';
import { formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';

export default class MicroDotsFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const done = AppStorage.get<number>('wearMicroDone') ?? 0;
    const target = AppStorage.get<number>('wearMicroTarget') ?? 4;
    return formBindingData.createFormBindingData({ microDone: done, microTarget: target });
  }

  onUpdateForm(formId: string): void {
    const done = AppStorage.get<number>('wearMicroDone') ?? 0;
    const target = AppStorage.get<number>('wearMicroTarget') ?? 4;
    const data = formBindingData.createFormBindingData({ microDone: done, microTarget: target });
    formProvider.updateForm(formId, data);
  }
}
